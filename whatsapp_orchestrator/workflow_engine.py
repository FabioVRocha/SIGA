"""Regras de negócio para execução de fluxos de WhatsApp."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from jinja2 import Environment, StrictUndefined
from sqlalchemy.orm import Session

from . import crud
from .models import ExecutionStatus, FlowExecution, FlowNode, NodeType
from .schemas import IncomingMessage, WebhookPayload
from .settings import Settings
from .whatsapp_client import WhatsAppClient
from .ai_client import AIChatClient

logger = logging.getLogger(__name__)

TEMPLATE_ENV = Environment(autoescape=False, undefined=StrictUndefined)


class WorkflowEngine:
    """Coordena o processamento de mensagens e nós de fluxo."""

    def __init__(
        self,
        db: Session,
        settings: Settings,
        whatsapp_client: Optional[WhatsAppClient] = None,
        ai_client: Optional[AIChatClient] = None,
        celery_app=None,
    ) -> None:
        self.db = db
        self.settings = settings
        self.celery_app = celery_app
        self.whatsapp_client = whatsapp_client or WhatsAppClient(settings)
        self.ai_client = ai_client or AIChatClient(settings)

    # ------------------------------------------------------------------ Webhook
    def process_webhook_payload(self, payload: WebhookPayload) -> None:
        """Processa o payload recebido pelo webhook do WhatsApp."""

        for entry in payload.entry:
            for change in entry.get("changes", []):
                value = change.get("value", {})
                contacts_map = {
                    contact["wa_id"]: contact.get("profile", {}).get("name")
                    for contact in value.get("contacts", [])
                }
                for message in value.get("messages", []):
                    try:
                        incoming = self._parse_message(message)
                    except ValueError:
                        logger.exception("Mensagem inválida recebida: %s", message)
                        continue
                    display_name = contacts_map.get(incoming.wa_id)
                    self.handle_incoming_message(incoming, display_name=display_name)

                for status in value.get("statuses", []):
                    logger.info("Status recebido do WhatsApp: %s", status)

    def _parse_message(self, message: Dict) -> IncomingMessage:
        wa_id = message.get("from")
        if not wa_id:
            raise ValueError("Mensagem sem remetente")
        msg_type = message.get("type", "text")
        text = None
        if msg_type == "text":
            text = message.get("text", {}).get("body")
        return IncomingMessage(wa_id=wa_id, text=text, type=msg_type, raw_payload=message)

    # ----------------------------------------------------------------- Execução
    def handle_incoming_message(self, incoming: IncomingMessage, display_name: Optional[str] = None) -> None:
        """Identifica a execução do fluxo e processa a mensagem recebida."""

        contact = crud.get_or_create_contact(self.db, incoming.wa_id, display_name=display_name)
        execution = crud.get_active_execution_for_contact(self.db, contact.id)

        if not execution:
            execution = self._start_default_flow(contact.id)
            if not execution:
                logger.warning("Nenhum fluxo configurado para iniciar conversas com %s", incoming.wa_id)
                return

        crud.log_execution_event(
            self.db,
            execution,
            event_type="incoming_message",
            payload={"text": incoming.text, "type": incoming.type},
            node_id=execution.current_node_id,
        )

        context = dict(execution.context)
        context["last_message"] = incoming.raw_payload
        context["last_message_type"] = incoming.type
        if incoming.text is not None:
            context["last_message_text"] = incoming.text
        execution = crud.update_execution_context(self.db, execution, context)

        self._execute_from_current_node(execution, inbound_message=incoming)

    def _start_default_flow(self, contact_id: int) -> Optional[FlowExecution]:
        default_flow_id = self.settings.default_flow_id
        if not default_flow_id:
            return None
        try:
            flow = crud.get_flow(self.db, default_flow_id)
        except Exception:
            logger.exception("Falha ao carregar fluxo padrão %s", default_flow_id)
            return None
        return crud.create_execution(self.db, flow, contact_id)

    def _execute_from_current_node(
        self,
        execution: FlowExecution,
        inbound_message: Optional[IncomingMessage] = None,
    ) -> None:
        node = execution.current_node
        if not node:
            logger.info("Execução %s sem nó atual, finalizando", execution.id)
            crud.mark_execution_status(self.db, execution, ExecutionStatus.COMPLETED)
            return

        keep_processing = True
        while node and keep_processing:
            try:
                next_node = self._process_node(execution, node, inbound_message)
            except Exception as exc:  # pragma: no cover - proteção adicional
                logger.exception("Erro ao processar nó %s da execução %s", node.id, execution.id)
                crud.mark_execution_status(
                    self.db, execution, ExecutionStatus.FAILED, last_error=str(exc)
                )
                raise

            if execution.status in {ExecutionStatus.WAITING_INPUT, ExecutionStatus.SCHEDULED}:
                keep_processing = False
                break

            if next_node is None:
                keep_processing = False
                break

            execution.current_node_id = next_node.id
            execution.updated_at = datetime.utcnow()
            self.db.commit()
            self.db.refresh(execution)
            node = next_node
            inbound_message = None

    def _process_node(
        self,
        execution: FlowExecution,
        node: FlowNode,
        inbound_message: Optional[IncomingMessage],
    ) -> Optional[FlowNode]:
        logger.info("Processando nó %s (%s) da execução %s", node.key, node.node_type, execution.id)
        if node.node_type == NodeType.SEND_MESSAGE:
            return self._handle_send_message(execution, node)
        if node.node_type == NodeType.WAIT_FOR_INPUT:
            return self._handle_wait_for_input(execution, node, inbound_message)
        if node.node_type == NodeType.DECISION:
            return self._handle_decision(execution, node)
        if node.node_type == NodeType.AI_COMPLETION:
            return self._handle_ai_completion(execution, node, inbound_message)
        if node.node_type == NodeType.END:
            crud.mark_execution_status(self.db, execution, ExecutionStatus.COMPLETED)
            return None
        logger.warning("Tipo de nó %s não suportado", node.node_type)
        return crud.get_next_node(node, execution.context)

    # --------------------------------------------------------- Handlers de nós
    def _handle_send_message(self, execution: FlowExecution, node: FlowNode) -> Optional[FlowNode]:
        message_template = node.config.get("message")
        if not message_template:
            logger.warning("Nó %s sem mensagem configurada", node.id)
            return crud.get_next_node(node, execution.context)

        context = dict(execution.context)
        try:
            message = message_template.format(**context)
        except Exception:  # pragma: no cover - falha de template
            logger.exception("Erro ao interpolar mensagem do nó %s", node.id)
            message = message_template

        response = self.whatsapp_client.send_text_message(
            to=execution.contact.whatsapp_id,
            message=message,
            preview_url=node.config.get("preview_url", False),
        )
        crud.log_execution_event(
            self.db,
            execution,
            event_type="message_sent",
            payload={"request": node.config, "response": response},
            node_id=node.id,
        )

        delay = node.config.get("delay_seconds")
        next_node = crud.get_next_node(node, execution.context)
        if delay and next_node:
            self._enqueue_delayed_node(execution, next_node, delay)
            crud.mark_execution_status(self.db, execution, ExecutionStatus.SCHEDULED)
            return None
        return next_node

    def _handle_wait_for_input(
        self,
        execution: FlowExecution,
        node: FlowNode,
        inbound_message: Optional[IncomingMessage],
    ) -> Optional[FlowNode]:
        if inbound_message is None:
            crud.mark_execution_status(self.db, execution, ExecutionStatus.WAITING_INPUT)
            return None

        target_key = node.config.get("context_key")
        if target_key and inbound_message.text:
            context = dict(execution.context)
            context[target_key] = inbound_message.text
            crud.update_execution_context(self.db, execution, context)

        crud.mark_execution_status(self.db, execution, ExecutionStatus.RUNNING)
        return crud.get_next_node(node, execution.context)

    def _handle_decision(self, execution: FlowExecution, node: FlowNode) -> Optional[FlowNode]:
        next_node = crud.get_next_node(node, execution.context)
        if not next_node:
            crud.mark_execution_status(self.db, execution, ExecutionStatus.COMPLETED)
        return next_node

    def _handle_ai_completion(
        self,
        execution: FlowExecution,
        node: FlowNode,
        inbound_message: Optional[IncomingMessage],
    ) -> Optional[FlowNode]:
        logger.info(
            "Gerando resposta de IA para o nó %s (%s) da execução %s",
            node.key,
            node.node_type,
            execution.id,
        )

        template_context = self._build_template_context(execution, inbound_message)
        context_key = node.config.get("context_key", f"{node.key}_response")
        alias_key = node.config.get("response_alias")
        history_key = node.config.get("history_context_key")

        history_messages: List[Dict[str, str]] = []
        if history_key:
            stored_history = execution.context.get(history_key)
            if isinstance(stored_history, list):
                for entry in stored_history:
                    if isinstance(entry, dict) and entry.get("role") and entry.get("content"):
                        history_messages.append(
                            {"role": str(entry["role"]), "content": str(entry["content"])}
                        )
        if history_messages:
            template_context.setdefault("history_messages", history_messages)

        prompt_template = node.config.get("prompt_template") or node.config.get("prompt")
        if prompt_template:
            user_prompt = self._render_template(prompt_template, template_context)
        else:
            user_prompt = template_context.get("inbound_text") or template_context.get("last_message_text")

        if not user_prompt:
            logger.warning(
                "Nó de IA %s não possui prompt configurado nem mensagem de entrada disponível",
                node.id,
            )
            return crud.get_next_node(node, execution.context)

        send_response = self._to_bool(node.config.get("send_response"), True)
        append_history = self._to_bool(node.config.get("append_history"), True)
        preview_url = self._to_bool(node.config.get("preview_url"), False)

        system_prompt_template = (
            node.config.get("system_prompt") or self.settings.ai_default_system_prompt
        )
        messages: List[Dict[str, str]] = []
        if system_prompt_template:
            system_prompt = self._render_template(system_prompt_template, template_context)
            messages.append({"role": "system", "content": system_prompt})

        if history_messages:
            messages.extend(history_messages)

        messages.append({"role": "user", "content": user_prompt})

        model = node.config.get("model") or self.settings.openai_default_model
        temperature = self._to_float(node.config.get("temperature"))
        max_tokens = self._to_int(node.config.get("max_tokens"))
        extra_body_config = node.config.get("extra_body")
        extra_body = extra_body_config if isinstance(extra_body_config, dict) else None

        context_snapshot = dict(execution.context)
        context_snapshot[f"{context_key}_prompt"] = user_prompt
        if alias_key and alias_key not in context_snapshot:
            context_snapshot[alias_key] = None

        if not self.ai_client.is_configured():
            logger.warning(
                "Cliente de IA não configurado. Nó %s será ignorado e apenas o prompt será salvo.",
                node.id,
            )
            execution = crud.update_execution_context(self.db, execution, context_snapshot)
            crud.log_execution_event(
                self.db,
                execution,
                event_type="ai_skipped",
                payload={"reason": "missing_credentials", "prompt": user_prompt},
                node_id=node.id,
            )
            return crud.get_next_node(node, execution.context)

        try:
            completion = self.ai_client.generate_message(
                messages=messages,
                model=model,
                temperature=temperature,
                max_tokens=max_tokens,
                extra_body=extra_body,
            )
        except Exception as exc:  # pragma: no cover - dependente do provedor externo
            logger.exception("Erro ao gerar resposta de IA no nó %s", node.id)
            crud.log_execution_event(
                self.db,
                execution,
                event_type="ai_error",
                payload={
                    "error": str(exc),
                    "request": {
                        "model": model,
                        "temperature": temperature,
                        "max_tokens": max_tokens,
                        "messages": messages,
                        "prompt": user_prompt,
                    },
                },
                node_id=node.id,
            )
            crud.mark_execution_status(self.db, execution, ExecutionStatus.FAILED, last_error=str(exc))
            raise

        response_text = completion.get("content", "").strip()

        request_payload: Dict[str, Any] = {"messages": messages, "model": model}
        if temperature is not None:
            request_payload["temperature"] = temperature
        if max_tokens is not None:
            request_payload["max_tokens"] = max_tokens
        if extra_body:
            request_payload["extra_body"] = extra_body

        crud.log_execution_event(
            self.db,
            execution,
            event_type="ai_completion",
            payload={"request": request_payload, "response": completion.get("raw")},
            node_id=node.id,
        )

        updated_context = dict(execution.context)
        updated_context[context_key] = response_text
        updated_context[f"{context_key}_prompt"] = user_prompt
        if alias_key:
            updated_context[alias_key] = response_text
        if append_history and history_key:
            existing_history = execution.context.get(history_key)
            history_store: List[Dict[str, str]] = []
            if isinstance(existing_history, list):
                history_store = list(existing_history)
            history_store.append({"role": "user", "content": user_prompt})
            history_store.append({"role": "assistant", "content": response_text})
            updated_context[history_key] = history_store
        if self._to_bool(node.config.get("store_raw_message"), False):
            updated_context[f"{context_key}_message"] = completion.get("message")
        if self._to_bool(node.config.get("store_full_response"), False):
            updated_context[f"{context_key}_raw_response"] = completion.get("raw")

        execution = crud.update_execution_context(self.db, execution, updated_context)

        if send_response:
            message_context = dict(execution.context)
            message_context.setdefault("ai_response", response_text)
            message_context.setdefault("ai_prompt", user_prompt)
            response_template = node.config.get("response_template")
            if response_template:
                outbound_message = self._render_template(response_template, message_context)
            else:
                outbound_message = response_text
            if not isinstance(outbound_message, str):
                outbound_message = str(outbound_message)
            if outbound_message.strip():
                whatsapp_response = self.whatsapp_client.send_text_message(
                    to=execution.contact.whatsapp_id,
                    message=outbound_message,
                    preview_url=preview_url,
                )
                crud.log_execution_event(
                    self.db,
                    execution,
                    event_type="message_sent",
                    payload={
                        "request": {
                            "message": outbound_message,
                            "preview_url": preview_url,
                        },
                        "response": whatsapp_response,
                        "meta": {"source": "ai_completion"},
                    },
                    node_id=node.id,
                )

        next_node = crud.get_next_node(node, execution.context)
        delay = node.config.get("delay_seconds")
        if delay and next_node:
            self._enqueue_delayed_node(execution, next_node, delay)
            crud.mark_execution_status(self.db, execution, ExecutionStatus.SCHEDULED)
            return None
        return next_node

    # ------------------------------------------------------------ Agendamentos
    def _enqueue_delayed_node(self, execution: FlowExecution, node: FlowNode, delay_seconds: int) -> None:
        eta = datetime.utcnow() + timedelta(seconds=int(delay_seconds))
        crud.schedule_action(self.db, execution, node, run_at=eta)
        if self.celery_app:
            self.celery_app.send_task(
                "whatsapp.execute_node",
                args=[execution.id, node.id],
                eta=eta,
            )

    # ------------------------------------------------------------ Utilidades
    def _build_template_context(
        self,
        execution: FlowExecution,
        inbound_message: Optional[IncomingMessage],
    ) -> Dict[str, Any]:
        context: Dict[str, Any] = dict(execution.context)

        last_message_payload = context.get("last_message")
        if isinstance(last_message_payload, dict):
            text_payload = last_message_payload.get("text")
            if isinstance(text_payload, dict):
                body = text_payload.get("body")
                if body and "last_message_text" not in context:
                    context["last_message_text"] = body

        if execution.contact:
            context.setdefault("contact_name", execution.contact.display_name)
            context.setdefault("contact_whatsapp_id", execution.contact.whatsapp_id)

        if inbound_message:
            context["inbound_message"] = inbound_message.raw_payload
            context["inbound_type"] = inbound_message.type
            context["inbound_text"] = inbound_message.text
            if inbound_message.text and "last_message_text" not in context:
                context["last_message_text"] = inbound_message.text

        return context

    def _render_template(self, template: str, context: Dict[str, Any]) -> str:
        try:
            return TEMPLATE_ENV.from_string(template).render(**context)
        except Exception:  # pragma: no cover - templates inválidos dependem do usuário
            logger.exception("Erro ao renderizar template dinâmico do nó")
            return template

    @staticmethod
    def _to_bool(value: Any, default: bool) -> bool:
        if value is None:
            return default
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return bool(value)
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"true", "1", "yes", "y", "sim"}:
                return True
            if normalized in {"false", "0", "no", "n", "nao", "não"}:
                return False
            return default
        return bool(value)

    @staticmethod
    def _to_float(value: Any) -> Optional[float]:
        if value is None or value == "":
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _to_int(value: Any) -> Optional[int]:
        if value is None or value == "":
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    def trigger_node(self, execution_id: int, node_id: int) -> None:
        execution = self.db.get(FlowExecution, execution_id)
        if not execution:
            logger.warning("Execução %s não encontrada ao disparar nó", execution_id)
            return
        node = self.db.get(FlowNode, node_id)
        if not node:
            logger.warning("Nó %s não encontrado", node_id)
            return
        execution.current_node_id = node.id
        execution.status = ExecutionStatus.RUNNING
        self.db.commit()
        self.db.refresh(execution)
        self._execute_from_current_node(execution)