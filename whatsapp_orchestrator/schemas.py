"""Esquemas Pydantic utilizados pelas rotas e pelo worker."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

from .models import ExecutionStatus, FlowStatus, NodeType


class FlowNodeBase(BaseModel):
    key: str = Field(..., description="Identificador único do nó dentro do fluxo.")
    node_type: NodeType
    config: Dict[str, Any] = Field(default_factory=dict)
    next_node_id: Optional[int] = None


class FlowNodeCreate(FlowNodeBase):
    pass


class FlowNodeUpdate(BaseModel):
    node_type: Optional[NodeType] = None
    config: Optional[Dict[str, Any]] = None
    next_node_id: Optional[int] = None


class FlowNodeRead(FlowNodeBase):
    id: int
    flow_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True


class FlowBase(BaseModel):
    name: str
    description: Optional[str] = None
    status: FlowStatus = FlowStatus.ACTIVE
    entry_node_id: Optional[int] = None


class FlowCreate(FlowBase):
    nodes: List[FlowNodeCreate] = Field(default_factory=list)


class FlowUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    status: Optional[FlowStatus] = None
    entry_node_id: Optional[int] = None


class FlowRead(FlowBase):
    id: int
    created_at: datetime
    updated_at: datetime
    nodes: List[FlowNodeRead] = Field(default_factory=list)

    class Config:
        orm_mode = True


class ContactRead(BaseModel):
    id: int
    whatsapp_id: str
    display_name: Optional[str]
    metadata: Dict[str, Any]
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True


class ExecutionRead(BaseModel):
    id: int
    flow_id: int
    contact_id: int
    current_node_id: Optional[int]
    status: ExecutionStatus
    context: Dict[str, Any]
    last_error: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True


class ExecutionLogRead(BaseModel):
    id: int
    execution_id: int
    node_id: Optional[int]
    event_type: str
    payload: Dict[str, Any]
    created_at: datetime

    class Config:
        orm_mode = True


class WebhookChallengeResponse(BaseModel):
    """Resposta enviada pelo webhook na verificação de assinatura do Meta."""

    hub_mode: str = Field(alias="hub.mode")
    hub_challenge: str = Field(alias="hub.challenge")
    hub_verify_token: str = Field(alias="hub.verify_token")


class IncomingMessage(BaseModel):
    """Estrutura mínima para uma mensagem recebida do WhatsApp."""

    wa_id: str = Field(..., description="Identificador do contato no WhatsApp")
    text: Optional[str] = Field(default=None, description="Conteúdo textual recebido")
    type: str = Field(default="text")
    raw_payload: Dict[str, Any] = Field(default_factory=dict)


class WebhookPayload(BaseModel):
    """Payload completo enviado pelo webhook do WhatsApp."""

    object: Optional[str] = None
    entry: List[Dict[str, Any]] = Field(default_factory=list)


class StartFlowRequest(BaseModel):
    flow_id: int
    whatsapp_id: str
    context: Dict[str, Any] = Field(default_factory=dict)
    display_name: Optional[str] = None