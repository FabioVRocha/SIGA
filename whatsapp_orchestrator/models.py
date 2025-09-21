"""Modelos relacionais que descrevem fluxos de WhatsApp."""

from __future__ import annotations

import enum
from datetime import datetime
from typing import Any, Dict, Optional

from sqlalchemy import JSON, Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class FlowStatus(str, enum.Enum):
    """Status possíveis de um fluxo configurado."""

    ACTIVE = "active"
    INACTIVE = "inactive"


class ExecutionStatus(str, enum.Enum):
    """Status da execução de um fluxo por contato."""

    RUNNING = "running"
    WAITING_INPUT = "waiting_input"
    SCHEDULED = "scheduled"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class NodeType(str, enum.Enum):
    """Tipos básicos de nós suportados."""

    SEND_MESSAGE = "send_message"
    WAIT_FOR_INPUT = "wait_for_input"
    DECISION = "decision"
    AI_COMPLETION = "ai_completion"
    END = "end"


class Flow(Base):
    __tablename__ = "workflow_flows"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    description: Mapped[Optional[str]] = mapped_column(Text)
    status: Mapped[FlowStatus] = mapped_column(Enum(FlowStatus), default=FlowStatus.ACTIVE)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )
    entry_node_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("workflow_nodes.id"))

    nodes: Mapped[list[FlowNode]] = relationship(
        "FlowNode", back_populates="flow", cascade="all, delete-orphan"
    )
    executions: Mapped[list[FlowExecution]] = relationship("FlowExecution", back_populates="flow")

    def __repr__(self) -> str:  # pragma: no cover - auxiliar de debug
        return f"<Flow id={self.id} name={self.name!r}>"


class FlowNode(Base):
    __tablename__ = "workflow_nodes"
    __table_args__ = (
        UniqueConstraint("flow_id", "key", name="uq_workflow_node_key"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    flow_id: Mapped[int] = mapped_column(Integer, ForeignKey("workflow_flows.id"), nullable=False)
    key: Mapped[str] = mapped_column(String(120), nullable=False)
    node_type: Mapped[NodeType] = mapped_column(Enum(NodeType), nullable=False)
    config: Mapped[Dict[str, Any]] = mapped_column(JSONB().with_variant(JSON, "sqlite"), default=dict)
    next_node_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("workflow_nodes.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    flow: Mapped[Flow] = relationship("Flow", back_populates="nodes", foreign_keys=[flow_id])
    next_node: Mapped[Optional[FlowNode]] = relationship("FlowNode", remote_side=[id])
    transitions: Mapped[list[FlowTransition]] = relationship(
        "FlowTransition", back_populates="source_node", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:  # pragma: no cover - auxiliar de debug
        return f"<FlowNode id={self.id} key={self.key!r} type={self.node_type}>"


class FlowTransition(Base):
    __tablename__ = "workflow_transitions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    source_node_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("workflow_nodes.id", ondelete="CASCADE"), nullable=False
    )
    target_node_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("workflow_nodes.id", ondelete="CASCADE"), nullable=False
    )
    condition: Mapped[Optional[str]] = mapped_column(Text)
    priority: Mapped[int] = mapped_column(Integer, default=0)

    source_node: Mapped[FlowNode] = relationship(
        "FlowNode", foreign_keys=[source_node_id], back_populates="transitions"
    )
    target_node: Mapped[FlowNode] = relationship("FlowNode", foreign_keys=[target_node_id])


class Contact(Base):
    __tablename__ = "workflow_contacts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    whatsapp_id: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    display_name: Mapped[Optional[str]] = mapped_column(String(200))
    metadata: Mapped[Dict[str, Any]] = mapped_column(JSONB().with_variant(JSON, "sqlite"), default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    executions: Mapped[list[FlowExecution]] = relationship("FlowExecution", back_populates="contact")


class FlowExecution(Base):
    __tablename__ = "workflow_executions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    flow_id: Mapped[int] = mapped_column(Integer, ForeignKey("workflow_flows.id"), nullable=False)
    contact_id: Mapped[int] = mapped_column(Integer, ForeignKey("workflow_contacts.id"), nullable=False)
    current_node_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("workflow_nodes.id"))
    status: Mapped[ExecutionStatus] = mapped_column(
        Enum(ExecutionStatus), default=ExecutionStatus.RUNNING, nullable=False
    )
    context: Mapped[Dict[str, Any]] = mapped_column(JSONB().with_variant(JSON, "sqlite"), default=dict)
    last_error: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    flow: Mapped[Flow] = relationship("Flow", back_populates="executions")
    contact: Mapped[Contact] = relationship("Contact", back_populates="executions")
    current_node: Mapped[Optional[FlowNode]] = relationship("FlowNode", foreign_keys=[current_node_id])
    logs: Mapped[list[ExecutionLog]] = relationship(
        "ExecutionLog", back_populates="execution", cascade="all, delete-orphan"
    )


class ExecutionLog(Base):
    __tablename__ = "workflow_execution_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    execution_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("workflow_executions.id", ondelete="CASCADE"), nullable=False
    )
    node_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("workflow_nodes.id"))
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    payload: Mapped[Dict[str, Any]] = mapped_column(JSONB().with_variant(JSON, "sqlite"), default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    execution: Mapped[FlowExecution] = relationship("FlowExecution", back_populates="logs")
    node: Mapped[Optional[FlowNode]] = relationship("FlowNode")


class ScheduledAction(Base):
    __tablename__ = "workflow_scheduled_actions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    execution_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("workflow_executions.id", ondelete="CASCADE"), nullable=False
    )
    node_id: Mapped[int] = mapped_column(Integer, ForeignKey("workflow_nodes.id"), nullable=False)
    run_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    payload: Mapped[Dict[str, Any]] = mapped_column(JSONB().with_variant(JSON, "sqlite"), default=dict)
    delivered: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    execution: Mapped[FlowExecution] = relationship("FlowExecution")
    node: Mapped[FlowNode] = relationship("FlowNode")