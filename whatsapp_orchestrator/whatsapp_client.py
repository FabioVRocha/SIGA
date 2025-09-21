"""Cliente HTTP simples para integrações com a WhatsApp Business Platform."""

from __future__ import annotations

import logging
from typing import Any, Dict

import requests

from .settings import Settings

logger = logging.getLogger(__name__)


class WhatsAppClient:
    """Envia mensagens via API oficial ou provedores compatíveis."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    @property
    def headers(self) -> Dict[str, str]:
        token = self._settings.whatsapp_access_token
        if not token:
            raise RuntimeError("Token de acesso do WhatsApp não configurado")
        return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    @property
    def base_url(self) -> str:
        if not self._settings.whatsapp_phone_number_id:
            raise RuntimeError("Número comercial do WhatsApp não configurado")
        return (
            f"{self._settings.whatsapp_api_base_url}/{self._settings.whatsapp_phone_number_id}"
        )

    def send_text_message(self, to: str, message: str, preview_url: bool = False) -> Dict[str, Any]:
        if not self._settings.whatsapp_access_token or not self._settings.whatsapp_phone_number_id:
            logger.warning(
                "Credenciais do WhatsApp ausentes. Mensagem para %s registrada como simulada.",
                to,
            )
            return {"status": "skipped", "to": to, "message": message}

        payload = {
            "messaging_product": "whatsapp",
            "to": to,
            "type": "text",
            "text": {"preview_url": preview_url, "body": message},
        }
        return self._post("/messages", payload)

    def mark_message_as_read(self, message_id: str) -> Dict[str, Any]:
        if not self._settings.whatsapp_access_token or not self._settings.whatsapp_phone_number_id:
            logger.warning(
                "Credenciais do WhatsApp ausentes. Confirmação de leitura %s ignorada.", message_id
            )
            return {"status": "skipped", "message_id": message_id}
        payload = {"messaging_product": "whatsapp", "status": "read", "message_id": message_id}
        return self._post("/messages", payload)

    def _post(self, path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        url = f"{self.base_url}{path}"
        logger.info("Enviando requisição POST para %s", url)
        response = requests.post(url, headers=self.headers, json=payload, timeout=30)
        try:
            response.raise_for_status()
        except requests.HTTPError:
            logger.exception("Erro na chamada à API do WhatsApp: %s", response.text)
            raise
        return response.json()

    def __repr__(self) -> str:  # pragma: no cover - debug
        return "WhatsAppClient(base_url=%s)" % self.base_url