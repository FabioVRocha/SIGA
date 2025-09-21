"""Integração com APScheduler para orquestrar atrasos e execuções recorrentes."""

from __future__ import annotations

import logging
from typing import Optional

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from . import crud
from .database import session_scope
from .settings import get_settings
from .tasks import celery_app

logger = logging.getLogger(__name__)

settings = get_settings()


def dispatch_pending_actions() -> None:
    """Enfileira ações atrasadas que ainda não foram executadas pelo worker."""

    with session_scope() as session:
        actions = crud.list_pending_scheduled_actions(session)
        for action in actions:
            logger.info(
                "Despachando ação agendada %s para execução %s (nó %s)",
                action.id,
                action.execution_id,
                action.node_id,
            )
            celery_app.send_task(
                "whatsapp.execute_node",
                args=[action.execution_id, action.node_id],
                eta=action.run_at,
            )
            action.delivered = True
        session.commit()


def create_scheduler(timezone: Optional[str] = None) -> AsyncIOScheduler:
    scheduler = AsyncIOScheduler(timezone=timezone or settings.scheduler_timezone)
    scheduler.add_job(
        dispatch_pending_actions,
        IntervalTrigger(seconds=30),
        id="workflow-dispatcher",
        replace_existing=True,
    )
    return scheduler