# siga_erp/config.py

import os
from dotenv import load_dotenv

# Carrega as variáveis de ambiente do arquivo .env
load_dotenv()

class Config:
    """
    Classe de configuração para o aplicativo Flask.
    Define as credenciais para ambos os bancos de dados (ERP e SIGA_DB)
    e a chave secreta.
    """
    # Configurações do banco de dados PostgreSQL principal (ERP)
    ERP_DB_HOST = os.getenv("DB_HOST", "localhost")
    ERP_DB_PORT = os.getenv("DB_PORT", "5432")
    ERP_DB_NAME = os.getenv("DB_NAME", "seu_banco_de_dados_erp") # Nome do seu banco de dados ERP
    ERP_DB_USER = os.getenv("DB_USER", "postgres")
    ERP_DB_PASSWORD = os.getenv("DB_PASSWORD", "password")

    # URI completa do banco de dados ERP para psycopg2
    ERP_DATABASE_URI = (
        f"postgresql://{ERP_DB_USER}:{ERP_DB_PASSWORD}@{ERP_DB_HOST}:{ERP_DB_PORT}/{ERP_DB_NAME}"
    )

    # Configurações do banco de dados PostgreSQL auxiliar (SIGA_DB)
    # Você pode usar as mesmas credenciais ou diferentes, dependendo da sua configuração
    SIGA_DB_HOST = os.getenv("SIGA_DB_HOST", "localhost")
    SIGA_DB_PORT = os.getenv("SIGA_DB_PORT", "5432")
    SIGA_DB_NAME = os.getenv("SIGA_DB_NAME", "siga_db") # Nome do novo banco de dados auxiliar
    SIGA_DB_USER = os.getenv("SIGA_DB_USER", "postgres")
    SIGA_DB_PASSWORD = os.getenv("SIGA_DB_PASSWORD", "password")

    # URI completa do banco de dados SIGA_DB para psycopg2
    SIGA_DATABASE_URI = (
        f"postgresql://{SIGA_DB_USER}:{SIGA_DB_PASSWORD}@{SIGA_DB_HOST}:{SIGA_DB_PORT}/{SIGA_DB_NAME}"
    )

    # Chave secreta para segurança do Flask (sessões, etc.)
    SECRET_KEY = os.getenv("SECRET_KEY", "uma_chave_secreta_muito_segura_e_longa_para_producao")
