# config.py

# --- Configurações do Banco de Dados PostgreSQL do ERP (Principal) ---
# ATENÇÃO: Substitua estas variáveis com as suas próprias credenciais do banco de dados do ERP.
DB_HOST = "45.161.184.156"  # Endereço do seu servidor PostgreSQL
DB_NAME = "madresilva"  # Nome do seu banco de dados do ERP
DB_USER = "postgres"  # Nome de usuário do PostgreSQL para o ERP
DB_PASS = "postgres"  # Senha do usuário do ERP
DB_PORT = "5433" # Porta do PostgreSQL (padrão é 5432)

# --- Configurações do Banco de Dados Auxiliar (SIGA_DB) ---
# Este banco será usado para tabelas auxiliares como usuários do sistema.
SIGA_DB_NAME = "siga_db" # Nome do seu banco de dados auxiliar SIGA

# Nome da tabela para armazenar parâmetros de usuário
USER_PARAMETERS_TABLE = "user_parameters"

# Chave secreta para sessões e mensagens flash (IMPORTANTE: Mude para um valor complexo e seguro em produção)
SECRET_KEY = 'sua_chave_secreta_muito_segura_e_complexa_aqui'

# Variáveis de exemplo para o rodapé (em um sistema real, viriam de um banco de dados ou configuração)
SYSTEM_VERSION = "1.0.0"
LOGGED_IN_USER = "Admin" # Será sobrescrito pelo nome de usuário da sessão
