"""Definição de tasks Celery responsáveis por executar nós."""

from __future__ import annotations

import logging

from celery import Celery

from .database import session_scope
from .settings import get_settings
from .workflow_engine import WorkflowEngine

logger = logging.getLogger(__name__)

settings = get_settings()

celery_app = Celery("whatsapp_orchestrator")
celery_app.conf.broker_url = settings.celery_broker_url
celery_app.conf.result_backend = settings.celery_result_backend
celery_app.conf.task_default_queue = "whatsapp_orchestrator"


@celery_app.task(name="whatsapp.execute_node")
def execute_node(execution_id: int, node_id: int) -> None:
    """Executa um nó específico, reabrindo a sessão de banco conforme necessário."""

    logger.info("Executando nó %s da execução %s via Celery", node_id, execution_id)
    with session_scope() as session:
        engine = WorkflowEngine(session, settings, celery_app=celery_app)
        engine.trigger_node(execution_id, node_id)