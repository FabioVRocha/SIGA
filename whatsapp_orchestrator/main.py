"""Aplicação FastAPI que expõe o orquestrador de fluxos."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import List, Optional
from urllib.parse import urlencode

from fastapi import Depends, FastAPI, Form, HTTPException, Request, status
from fastapi.responses import JSONResponse, PlainTextResponse, RedirectResponse, TemplateResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from . import crud, schemas
from .database import Base, engine, get_session
from .scheduler import create_scheduler
from .settings import Settings, get_settings
from .tasks import celery_app
from .workflow_engine import WorkflowEngine
from .models import FlowStatus, NodeType

logger = logging.getLogger(__name__)

app = FastAPI(title="SIGA WhatsApp Orchestrator", version="1.0.0")

templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))
templates.env.globals.update(
    {
        "FlowStatus": FlowStatus,
        "NodeType": NodeType,
    }
)


def _flow_console_context(
    request: Request,
    flow,
    message: Optional[str] = None,
    error: Optional[str] = None,
):
    """Monta o contexto padrão para telas de detalhe de fluxo."""

    return {
        "request": request,
        "flow": flow,
        "flow_statuses": list(FlowStatus),
        "node_types": list(NodeType),
        "message": message,
        "error": error,
        "new_node_form": None,
        "open_node_id": None,
    }


def _parse_config(config_json: str) -> dict:
    """Converte texto JSON em dicionário, aceitando entradas vazias."""

    if not config_json.strip():
        return {}
    return json.loads(config_json)


@app.on_event("startup")
async def on_startup() -> None:
    Base.metadata.create_all(bind=engine)
    scheduler = create_scheduler()
    scheduler.start()
    app.state.scheduler = scheduler
    logger.info("Orquestrador inicializado com sucesso")


@app.on_event("shutdown")
async def on_shutdown() -> None:
    scheduler = getattr(app.state, "scheduler", None)
    if scheduler:
        scheduler.shutdown(wait=False)


@app.get("/health")
async def healthcheck() -> dict:
    return {"status": "ok"}


@app.get("/", name="console_home")
async def console_home(
    request: Request,
    db: Session = Depends(get_session),
) -> TemplateResponse:
    flows = crud.list_flows(db)
    context = {
        "request": request,
        "flows": flows,
        "flow_statuses": list(FlowStatus),
    }
    return templates.TemplateResponse("flows/list.html", context)


@app.get("/console/flows/new", name="new_flow_form")
async def new_flow_form(request: Request) -> TemplateResponse:
    context = {
        "request": request,
        "flow_statuses": list(FlowStatus),
        "form_values": {"status": FlowStatus.ACTIVE.value},
    }
    return templates.TemplateResponse("flows/new.html", context)


@app.post("/console/flows/new", name="create_flow_form")
async def create_flow_form(
    request: Request,
    db: Session = Depends(get_session),
    name: str = Form(...),
    description: str = Form(""),
    status_value: str = Form(FlowStatus.ACTIVE.value),
) -> RedirectResponse | TemplateResponse:
    try:
        status_enum = FlowStatus(status_value)
    except ValueError:
        context = {
            "request": request,
            "flow_statuses": list(FlowStatus),
            "form_values": {
                "name": name,
                "description": description,
                "status": status_value,
            },
            "error": "Status informado é inválido.",
        }
        return templates.TemplateResponse("flows/new.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    payload = schemas.FlowCreate(
        name=name.strip(),
        description=description.strip() or None,
        status=status_enum,
    )

    try:
        flow = crud.create_flow(db, payload)
    except Exception:  # noqa: BLE001 - queremos qualquer erro de integridade
        db.rollback()
        context = {
            "request": request,
            "flow_statuses": list(FlowStatus),
            "form_values": {
                "name": name,
                "description": description,
                "status": status_value,
            },
            "error": "Não foi possível criar o fluxo. Verifique se o nome é único e tente novamente.",
        }
        return templates.TemplateResponse("flows/new.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    target = request.url_for("view_flow", flow_id=str(flow.id))
    url = f"{target}?{urlencode({'message': 'Fluxo criado com sucesso'})}"
    return RedirectResponse(url=url, status_code=status.HTTP_303_SEE_OTHER)


@app.get("/console/flows/{flow_id}", name="view_flow")
async def view_flow(
    flow_id: int,
    request: Request,
    db: Session = Depends(get_session),
) -> TemplateResponse:
    flow = crud.get_flow(db, flow_id)
    message = request.query_params.get("message")
    error = request.query_params.get("error")
    context = _flow_console_context(request, flow, message=message, error=error)
    return templates.TemplateResponse("flows/detail.html", context)


@app.post("/console/flows/{flow_id}", name="update_flow_form")
async def update_flow_form(
    flow_id: int,
    request: Request,
    db: Session = Depends(get_session),
    name: str = Form(...),
    description: str = Form(""),
    status_value: str = Form(FlowStatus.ACTIVE.value),
    entry_node_id: str = Form(""),
) -> RedirectResponse | TemplateResponse:
    flow = crud.get_flow(db, flow_id)
    try:
        status_enum = FlowStatus(status_value)
    except ValueError:
        context = _flow_console_context(request, flow, error="Status informado é inválido.")
        context["form_values"] = {
            "name": name,
            "description": description,
            "status": status_value,
            "entry_node_id": entry_node_id,
        }
        return templates.TemplateResponse("flows/detail.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    next_entry = int(entry_node_id) if entry_node_id else None

    payload = schemas.FlowUpdate(
        name=name.strip(),
        description=description.strip() or None,
        status=status_enum,
        entry_node_id=next_entry,
    )

    try:
        crud.update_flow(db, flow, payload)
    except Exception:  # noqa: BLE001 - feedback genérico
        db.rollback()
        context = _flow_console_context(
            request,
            flow,
            error="Não foi possível atualizar o fluxo. Revise os dados e tente novamente.",
        )
        return templates.TemplateResponse("flows/detail.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    target = request.url_for("view_flow", flow_id=str(flow.id))
    url = f"{target}?{urlencode({'message': 'Fluxo atualizado com sucesso'})}"
    return RedirectResponse(url=url, status_code=status.HTTP_303_SEE_OTHER)


@app.post("/console/flows/{flow_id}/nodes", name="add_node_form")
async def add_node_form(
    flow_id: int,
    request: Request,
    db: Session = Depends(get_session),
    key: str = Form(...),
    node_type: str = Form(...),
    config_json: str = Form(""),
    next_node_id: str = Form(""),
) -> RedirectResponse | TemplateResponse:
    flow = crud.get_flow(db, flow_id)
    try:
        node_type_enum = NodeType(node_type)
    except ValueError:
        context = _flow_console_context(request, flow, error="Tipo de nó informado é inválido.")
        context["new_node_form"] = {
            "key": key,
            "node_type": node_type,
            "config_json": config_json,
            "next_node_id": next_node_id,
        }
        return templates.TemplateResponse("flows/detail.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    try:
        config = _parse_config(config_json)
    except ValueError:
        context = _flow_console_context(
            request,
            flow,
            error="Configuração inválida. Utilize um JSON válido.",
        )
        context["new_node_form"] = {
            "key": key,
            "node_type": node_type,
            "config_json": config_json,
            "next_node_id": next_node_id,
        }
        return templates.TemplateResponse("flows/detail.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    next_id = int(next_node_id) if next_node_id else None
    payload = schemas.FlowNodeCreate(
        key=key.strip(),
        node_type=node_type_enum,
        config=config,
        next_node_id=next_id,
    )

    try:
        node = crud.create_node(db, flow, payload)
        db.commit()
        db.refresh(node)
    except Exception:
        db.rollback()
        context = _flow_console_context(
            request,
            flow,
            error="Não foi possível criar o nó. Verifique se a chave é única e o JSON é válido.",
        )
        context["new_node_form"] = {
            "key": key,
            "node_type": node_type,
            "config_json": config_json,
            "next_node_id": next_node_id,
        }
        return templates.TemplateResponse("flows/detail.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    target = request.url_for("view_flow", flow_id=str(flow.id))
    url = f"{target}?{urlencode({'message': 'Nó criado com sucesso'})}"
    return RedirectResponse(url=url, status_code=status.HTTP_303_SEE_OTHER)


@app.post("/console/flows/{flow_id}/nodes/{node_id}", name="update_node_form")
async def update_node_form(
    flow_id: int,
    node_id: int,
    request: Request,
    db: Session = Depends(get_session),
    node_type: str = Form(...),
    config_json: str = Form(""),
    next_node_id: str = Form(""),
) -> RedirectResponse | TemplateResponse:
    flow = crud.get_flow(db, flow_id)
    node = crud.get_node(db, node_id)

    try:
        node_type_enum = NodeType(node_type)
    except ValueError:
        context = _flow_console_context(request, flow, error="Tipo de nó informado é inválido.")
        context["open_node_id"] = node_id
        context["new_node_form"] = None
        return templates.TemplateResponse("flows/detail.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    try:
        config = _parse_config(config_json)
    except ValueError:
        context = _flow_console_context(
            request,
            flow,
            error="Configuração inválida. Utilize um JSON válido.",
        )
        context["open_node_id"] = node_id
        context["new_node_form"] = None
        return templates.TemplateResponse("flows/detail.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    payload = schemas.FlowNodeUpdate(
        node_type=node_type_enum,
        config=config,
        next_node_id=int(next_node_id) if next_node_id else None,
    )

    try:
        crud.update_node(db, node, payload)
    except Exception:
        db.rollback()
        context = _flow_console_context(
            request,
            flow,
            error="Não foi possível atualizar o nó. Verifique se os dados estão corretos.",
        )
        context["open_node_id"] = node_id
        return templates.TemplateResponse("flows/detail.html", context, status_code=status.HTTP_400_BAD_REQUEST)

    target = request.url_for("view_flow", flow_id=str(flow.id))
    url = f"{target}?{urlencode({'message': 'Nó atualizado com sucesso'})}"
    return RedirectResponse(url=url, status_code=status.HTTP_303_SEE_OTHER)


@app.post("/console/flows/{flow_id}/nodes/{node_id}/delete", name="delete_node_form")
async def delete_node_form(
    flow_id: int,
    node_id: int,
    request: Request,
    db: Session = Depends(get_session),
) -> RedirectResponse:
    flow = crud.get_flow(db, flow_id)
    node = crud.get_node(db, node_id)
    crud.delete_node(db, node)
    target = request.url_for("view_flow", flow_id=str(flow.id))
    url = f"{target}?{urlencode({'message': 'Nó removido com sucesso'})}"
    return RedirectResponse(url=url, status_code=status.HTTP_303_SEE_OTHER)


@app.get("/webhook/whatsapp")
async def verify_webhook(request: Request, settings: Settings = Depends(get_settings)) -> PlainTextResponse:
    verify_token = request.query_params.get("hub.verify_token")
    challenge = request.query_params.get("hub.challenge", "")
    if settings.webhook_verify_token and verify_token != settings.webhook_verify_token:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid token")
    return PlainTextResponse(content=challenge)


@app.post("/webhook/whatsapp")
async def receive_webhook(
    payload: schemas.WebhookPayload,
    db: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> JSONResponse:
    engine_service = WorkflowEngine(db, settings, celery_app=celery_app)
    engine_service.process_webhook_payload(payload)
    return JSONResponse({"status": "received"})


@app.get("/flows", response_model=List[schemas.FlowRead])
async def list_flows(db: Session = Depends(get_session)) -> List[schemas.FlowRead]:
    flows = crud.list_flows(db)
    return flows


@app.post("/flows", response_model=schemas.FlowRead, status_code=status.HTTP_201_CREATED)
async def create_flow(payload: schemas.FlowCreate, db: Session = Depends(get_session)) -> schemas.FlowRead:
    flow = crud.create_flow(db, payload)
    return flow


@app.get("/flows/{flow_id}", response_model=schemas.FlowRead)
async def get_flow(flow_id: int, db: Session = Depends(get_session)) -> schemas.FlowRead:
    try:
        flow = crud.get_flow(db, flow_id)
    except Exception:  # pragma: no cover - falha tratada com HTTP 404
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Fluxo não encontrado")
    return flow


@app.patch("/flows/{flow_id}", response_model=schemas.FlowRead)
async def update_flow(
    flow_id: int,
    payload: schemas.FlowUpdate,
    db: Session = Depends(get_session),
) -> schemas.FlowRead:
    flow = crud.get_flow(db, flow_id)
    flow = crud.update_flow(db, flow, payload)
    return flow


@app.post("/flows/{flow_id}/nodes", response_model=schemas.FlowNodeRead, status_code=status.HTTP_201_CREATED)
async def add_node(
    flow_id: int,
    payload: schemas.FlowNodeCreate,
    db: Session = Depends(get_session),
) -> schemas.FlowNodeRead:
    flow = crud.get_flow(db, flow_id)
    node = crud.create_node(db, flow, payload)
    db.commit()
    db.refresh(node)
    return node


@app.patch("/flows/{flow_id}/nodes/{node_id}", response_model=schemas.FlowNodeRead)
async def update_node(
    flow_id: int,
    node_id: int,
    payload: schemas.FlowNodeUpdate,
    db: Session = Depends(get_session),
) -> schemas.FlowNodeRead:
    crud.get_flow(db, flow_id)
    node = crud.get_node(db, node_id)
    node = crud.update_node(db, node, payload)
    return node


@app.delete("/flows/{flow_id}/nodes/{node_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_node(flow_id: int, node_id: int, db: Session = Depends(get_session)) -> None:
    crud.get_flow(db, flow_id)
    node = crud.get_node(db, node_id)
    crud.delete_node(db, node)


@app.post("/flows/start", response_model=schemas.ExecutionRead, status_code=status.HTTP_201_CREATED)
async def start_flow(
    payload: schemas.StartFlowRequest,
    db: Session = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> schemas.ExecutionRead:
    flow = crud.get_flow(db, payload.flow_id)
    contact = crud.get_or_create_contact(db, payload.whatsapp_id, display_name=payload.display_name)
    execution = crud.create_execution(db, flow, contact.id, context=payload.context)
    engine_service = WorkflowEngine(db, settings, celery_app=celery_app)
    if execution.current_node_id:
        engine_service.trigger_node(execution.id, execution.current_node_id)
        db.refresh(execution)
    return execution