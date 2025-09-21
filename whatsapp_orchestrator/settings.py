"""Configurações centralizadas para o orquestrador de fluxos do WhatsApp."""

from functools import lru_cache
from typing import Optional

from pydantic import BaseSettings, Field

try:
    from config import (
        DB_HOST as DEFAULT_DB_HOST,
        DB_NAME as DEFAULT_DB_NAME,
        DB_PASS as DEFAULT_DB_PASS,
        DB_PORT as DEFAULT_DB_PORT,
        DB_USER as DEFAULT_DB_USER,
        SIGA_DB_NAME as DEFAULT_SIGA_DB_NAME,
    )
except ModuleNotFoundError:  # pragma: no cover - fallback para execução isolada
    DEFAULT_DB_HOST = "45.161.184.156"
    DEFAULT_DB_NAME = "postgres"
    DEFAULT_DB_PASS = "postgres"
    DEFAULT_DB_PORT = "5433"
    DEFAULT_DB_USER = "postgres"
    DEFAULT_SIGA_DB_NAME = "siga_db"


class Settings(BaseSettings):
    """Parâmetros de configuração com suporte a variáveis de ambiente."""

    db_host: str = Field(default=DEFAULT_DB_HOST, description="Host do banco de dados.")
    db_name: str = Field(
        default=DEFAULT_SIGA_DB_NAME,
        description="Nome do banco que armazenará os fluxos e execuções.",
    )
    db_user: str = Field(default=DEFAULT_DB_USER, description="Usuário do banco de dados.")
    db_password: str = Field(default=DEFAULT_DB_PASS, description="Senha do banco de dados.")
    db_port: str = Field(default=DEFAULT_DB_PORT, description="Porta do banco de dados.")

    celery_broker_url: str = Field(
        default="redis://localhost:6379/0",
        description="URL de conexão com o broker do Celery (ex.: Redis).",
    )
    celery_result_backend: str = Field(
        default="redis://localhost:6379/1",
        description="Backend para armazenamento de resultados do Celery.",
    )

    scheduler_timezone: str = Field(
        default="UTC", description="Timezone padrão para o agendador de tarefas."
    )

    whatsapp_api_base_url: str = Field(
        default="https://graph.facebook.com/v18.0",
        description="Endpoint base para chamadas à API do WhatsApp Cloud.",
    )
    whatsapp_phone_number_id: Optional[str] = Field(
        default=None, description="Identificador do número comercial no WhatsApp."
    )
    whatsapp_access_token: Optional[str] = Field(
        default=None, description="Token de acesso à API do WhatsApp.", repr=False
    )
    webhook_verify_token: Optional[str] = Field(
        default=None, description="Token utilizado na validação do webhook do Meta."
    )

    openai_api_key: Optional[str] = Field(
        default=None,
        description="Chave de acesso utilizada para chamadas à API de IA (ex.: OpenAI).",
        repr=False,
    )
    openai_api_base: str = Field(
        default="https://api.openai.com/v1",
        description="Endpoint base compatível com a API do OpenAI para chamadas de IA.",
    )
    openai_default_model: str = Field(
        default="gpt-3.5-turbo",
        description="Modelo padrão utilizado para gerar respostas inteligentes.",
    )
    openai_timeout_seconds: int = Field(
        default=30,
        description="Tempo máximo (em segundos) aguardado por uma resposta do provedor de IA.",
    )
    ai_default_system_prompt: Optional[str] = Field(
        default="Você é um assistente virtual que apoia usuários do SIGA via WhatsApp.",
        description="Instrução base aplicada às conversas quando não houver prompt customizado.",
    )

    default_flow_id: Optional[int] = Field(
        default=None,
        description="Identificador do fluxo padrão acionado para novos contatos.",
    )

    class Config:
        env_file = ".env"
        env_prefix = "WORKFLOW_"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Retorna as configurações com cache para evitar reprocessamento."""

    return Settings()