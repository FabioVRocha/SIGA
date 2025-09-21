"""Funções utilitárias para manipular o banco do orquestrador."""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from sqlalchemy import asc, select
from sqlalchemy.orm import Session

from . import schemas
from .models import ExecutionLog, ExecutionStatus, Flow, FlowExecution, FlowNode, FlowTransition, ScheduledAction


def list_flows(db: Session) -> List[Flow]:
    return db.execute(select(Flow).order_by(asc(Flow.name))).scalars().all()


def get_flow(db: Session, flow_id: int) -> Flow:
    statement = select(Flow).where(Flow.id == flow_id)
    flow = db.execute(statement).scalar_one()
    return flow


def get_flow_by_name(db: Session, name: str) -> Flow:
    statement = select(Flow).where(Flow.name == name)
    return db.execute(statement).scalar_one()


def create_flow(db: Session, payload: schemas.FlowCreate) -> Flow:
    flow = Flow(
        name=payload.name,
        description=payload.description,
        status=payload.status,
    )
    db.add(flow)
    db.flush()

    created_nodes = []
    for node_payload in payload.nodes:
        created_nodes.append(create_node(db, flow, node_payload))

    if payload.entry_node_id:
        flow.entry_node_id = payload.entry_node_id
    elif created_nodes:
        flow.entry_node_id = created_nodes[0].id

    db.commit()
    db.refresh(flow)
    return flow


def update_flow(db: Session, flow: Flow, payload: schemas.FlowUpdate) -> Flow:
    for field, value in payload.dict(exclude_unset=True).items():
        setattr(flow, field, value)
    db.commit()
    db.refresh(flow)
    return flow


def create_node(db: Session, flow: Flow, payload: schemas.FlowNodeCreate) -> FlowNode:
    node = FlowNode(
        flow_id=flow.id,
        key=payload.key,
        node_type=payload.node_type,
        config=payload.config,
        next_node_id=payload.next_node_id,
    )
    db.add(node)
    db.flush()
    return node


def update_node(db: Session, node: FlowNode, payload: schemas.FlowNodeUpdate) -> FlowNode:
    for field, value in payload.dict(exclude_unset=True).items():
        setattr(node, field, value)
    db.commit()
    db.refresh(node)
    return node


def delete_node(db: Session, node: FlowNode) -> None:
    db.delete(node)
    db.commit()


def get_node(db: Session, node_id: int) -> FlowNode:
    statement = select(FlowNode).where(FlowNode.id == node_id)
    return db.execute(statement).scalar_one()


def get_active_execution_for_contact(db: Session, contact_id: int) -> Optional[FlowExecution]:
    statement = select(FlowExecution).where(
        FlowExecution.contact_id == contact_id,
        FlowExecution.status.in_([ExecutionStatus.RUNNING, ExecutionStatus.WAITING_INPUT, ExecutionStatus.SCHEDULED]),
    )
    return db.execute(statement).scalars().first()


def create_contact(db: Session, whatsapp_id: str, display_name: Optional[str] = None) -> schemas.ContactRead:
    from .models import Contact  # import tardio para evitar ciclos

    contact = Contact(whatsapp_id=whatsapp_id, display_name=display_name)
    db.add(contact)
    db.commit()
    db.refresh(contact)
    return contact


def get_or_create_contact(db: Session, whatsapp_id: str, display_name: Optional[str] = None):
    from .models import Contact

    statement = select(Contact).where(Contact.whatsapp_id == whatsapp_id)
    result = db.execute(statement).scalar_one_or_none()
    if result:
        if display_name and result.display_name != display_name:
            result.display_name = display_name
            db.commit()
            db.refresh(result)
        return result

    return create_contact(db, whatsapp_id=whatsapp_id, display_name=display_name)


def create_execution(
    db: Session,
    flow: Flow,
    contact_id: int,
    context: Optional[dict] = None,
    start_node: Optional[FlowNode] = None,
) -> FlowExecution:
    node = start_node or db.get(FlowNode, flow.entry_node_id)
    execution = FlowExecution(
        flow_id=flow.id,
        contact_id=contact_id,
        current_node_id=node.id if node else None,
        status=ExecutionStatus.RUNNING,
        context=context or {},
    )
    db.add(execution)
    db.commit()
    db.refresh(execution)
    return execution


def mark_execution_status(db: Session, execution: FlowExecution, status: ExecutionStatus, last_error: Optional[str] = None) -> None:
    execution.status = status
    execution.last_error = last_error
    execution.updated_at = datetime.utcnow()
    db.commit()


def update_execution_context(db: Session, execution: FlowExecution, context: dict) -> FlowExecution:
    execution.context = context
    execution.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(execution)
    return execution


def log_execution_event(
    db: Session,
    execution: FlowExecution,
    event_type: str,
    payload: Optional[dict] = None,
    node_id: Optional[int] = None,
) -> ExecutionLog:
    log = ExecutionLog(
        execution_id=execution.id,
        node_id=node_id,
        event_type=event_type,
        payload=payload or {},
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    return log


def get_next_node_from_transitions(node: FlowNode, context: dict) -> Optional[FlowNode]:
    if not node.transitions:
        return node.next_node

    ordered = sorted(node.transitions, key=lambda transition: transition.priority)
    for transition in ordered:
        if not transition.condition:
            return transition.target_node
        if evaluate_condition(transition.condition, context):
            return transition.target_node
    return None


def get_next_node(node: FlowNode, context: dict) -> Optional[FlowNode]:
    candidate = get_next_node_from_transitions(node, context)
    if candidate is not None:
        return candidate
    return node.next_node


def schedule_action(
    db: Session,
    execution: FlowExecution,
    node: FlowNode,
    run_at: datetime,
    payload: Optional[dict] = None,
) -> ScheduledAction:
    scheduled = ScheduledAction(
        execution_id=execution.id,
        node_id=node.id,
        run_at=run_at,
        payload=payload or {},
    )
    db.add(scheduled)
    db.commit()
    db.refresh(scheduled)
    return scheduled


def list_pending_scheduled_actions(db: Session, limit: int = 100) -> List[ScheduledAction]:
    statement = (
        select(ScheduledAction)
        .where(ScheduledAction.delivered.is_(False), ScheduledAction.run_at <= datetime.utcnow())
        .order_by(asc(ScheduledAction.run_at))
        .limit(limit)
    )
    return db.execute(statement).scalars().all()


# --- Avaliação de expressões condicionais ---------------------------------

import ast
import operator as op


ALLOWED_OPERATORS = {
    ast.Eq: op.eq,
    ast.NotEq: op.ne,
    ast.Lt: op.lt,
    ast.LtE: op.le,
    ast.Gt: op.gt,
    ast.GtE: op.ge,
    ast.And: lambda a, b: a and b,
    ast.Or: lambda a, b: a or b,
    ast.Not: op.not_,
    ast.Is: op.is_,
    ast.IsNot: op.is_not,
    ast.In: lambda a, b: a in b,
    ast.NotIn: lambda a, b: a not in b,
}


class ConditionEvaluator(ast.NodeVisitor):
    """Avalia expressões booleanas simples usando AST para garantir segurança."""

    def __init__(self, context: dict):
        self.context = context

    def visit(self, node):  # type: ignore[override]
        return super().visit(node)

    def visit_Expression(self, node: ast.Expression):  # noqa: N802
        return self.visit(node.body)

    def visit_BoolOp(self, node: ast.BoolOp):  # noqa: N802
        op_type = type(node.op)
        if op_type not in ALLOWED_OPERATORS:
            raise ValueError(f"Operador booleano {op_type} não permitido")
        result = self.visit(node.values[0])
        for value in node.values[1:]:
            result = ALLOWED_OPERATORS[op_type](result, self.visit(value))
        return result

    def visit_Compare(self, node: ast.Compare):  # noqa: N802
        left = self.visit(node.left)
        result = True
        for operator, comparator in zip(node.ops, node.comparators):
            op_type = type(operator)
            if op_type not in ALLOWED_OPERATORS:
                raise ValueError(f"Operador {op_type} não permitido")
            right = self.visit(comparator)
            result = ALLOWED_OPERATORS[op_type](left, right)
            left = right
        return result

    def visit_Name(self, node: ast.Name):  # noqa: N802
        if node.id not in self.context:
            raise ValueError(f"Variável {node.id} não encontrada no contexto")
        return self.context[node.id]

    def visit_Constant(self, node: ast.Constant):  # noqa: N802
        return node.value

    def generic_visit(self, node):  # pragma: no cover - segurança
        raise ValueError(f"Expressão {type(node)} não suportada")


def evaluate_condition(expression: str, context: dict) -> bool:
    tree = ast.parse(expression, mode="eval")
    evaluator = ConditionEvaluator(context)
    return bool(evaluator.visit(tree))