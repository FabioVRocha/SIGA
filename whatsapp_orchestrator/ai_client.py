"""Cliente simples para interagir com provedores de IA compatíveis com a API do OpenAI."""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

import requests

from .settings import Settings

logger = logging.getLogger(__name__)


class AIChatClient:
    """Envolve chamadas à API de chat completion do OpenAI (ou compatíveis)."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    # ------------------------------------------------------------------ Helpers
    def is_configured(self) -> bool:
        """Indica se a integração está habilitada (chave configurada)."""

        return bool(self._settings.openai_api_key)

    @property
    def _headers(self) -> Dict[str, str]:
        if not self.is_configured():
            raise RuntimeError("Chave da API de IA não configurada")
        return {
            "Authorization": f"Bearer {self._settings.openai_api_key}",
            "Content-Type": "application/json",
        }

    @property
    def _base_url(self) -> str:
        return self._settings.openai_api_base.rstrip("/")

    # -------------------------------------------------------------- Chat API
    def chat_completion(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        extra_body: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Executa uma chamada à API de chat completions."""

        if not messages:
            raise ValueError("É necessário informar ao menos uma mensagem para a IA")

        payload: Dict[str, Any] = {
            "model": model or self._settings.openai_default_model,
            "messages": messages,
        }
        if temperature is not None:
            payload["temperature"] = float(temperature)
        if max_tokens is not None:
            payload["max_tokens"] = int(max_tokens)
        if extra_body:
            payload.update(extra_body)

        url = f"{self._base_url}/chat/completions"
        timeout = self._settings.openai_timeout_seconds

        logger.info(
            "Solicitando completion de IA: modelo=%s, mensagens=%s", payload["model"], len(messages)
        )
        try:
            response = requests.post(url, headers=self._headers, json=payload, timeout=timeout)
            response.raise_for_status()
        except requests.RequestException as exc:  # pragma: no cover - erros de rede variam
            logger.exception("Erro ao chamar o provedor de IA: %s", exc)
            raise

        return response.json()

    def generate_message(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        extra_body: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Obtém a mensagem gerada pelo provedor e normaliza o retorno."""

        data = self.chat_completion(
            messages=messages,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            extra_body=extra_body,
        )

        choices = data.get("choices", [])
        if not choices:
            raise ValueError("Resposta do provedor de IA não contém escolhas")

        message = choices[0].get("message")
        if not message:
            raise ValueError("Resposta do provedor de IA não contém mensagem gerada")

        content = message.get("content", "")
        if not isinstance(content, str):
            content = str(content)

        return {
            "content": content,
            "message": message,
            "raw": data,
        }


__all__ = ["AIChatClient"]