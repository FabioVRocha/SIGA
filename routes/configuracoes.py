# siga_erp/routes/configuracoes.py

from flask import Blueprint, render_template, request, current_app, flash, redirect, url_for
from datetime import datetime

# Cria um Blueprint para as rotas de configurações
configuracoes_bp = Blueprint('configuracoes', __name__)

@configuracoes_bp.route('/', methods=['GET', 'POST'])
def index():
    """
    Rota para a página de configurações.
    Permite visualizar e salvar os tipos de transação permitidos no siga_db.
    Busca transações disponíveis do banco de dados ERP.
    """
    # Acessa as instâncias de DBManager do objeto app
    db_erp = current_app.db_erp
    db_siga = current_app.db_siga

    tipos_transacao_permitidos_list = [] # Agora armazena uma lista de IDs
    transacoes_disponiveis = []
    mensagem = ""
    mensagem_tipo = "" # 'success' ou 'error'

    try:
        # Conecta ao banco de dados ERP para buscar as transações disponíveis
        db_erp.connect()
        # CORREÇÃO: Alterado 'trsname' para 'trsnome'
        transacoes_disponiveis = db_erp.fetch_all("SELECT transacao, trsnome FROM transa ORDER BY trsnome")
        db_erp.disconnect() # Desconecta após buscar as transações

        # Conecta ao banco de dados SIGA_DB para as operações de configuração
        db_siga.connect()

        # Busca a configuração atual como string e converte para lista
        config = db_siga.fetch_one("SELECT valor_configuracao FROM configuracoes WHERE nome_configuracao = 'tipos_transacao_permitidos'")
        if config and config[0]:
            # Converte a string de IDs separados por vírgula em uma lista
            tipos_transacao_permitidos_list = [t.strip() for t in config[0].split(',') if t.strip()]

        if request.method == 'POST':
            # Obtém a lista de transações selecionadas pelos checkboxes
            selected_transactions_from_form = request.form.getlist('selected_transactions')
            # Garante que a lista contenha apenas IDs válidos (strings limpas)
            novos_tipos_list = [t.strip() for t in selected_transactions_from_form if t.strip()]

            if novos_tipos_list:
                # Validação: verificar se os IDs selecionados existem na tabela 'transa' (no ERP DB)
                # Cria uma string de placeholders para a consulta IN
                placeholders = ', '.join(['%s'] * len(novos_tipos_list))
                # Conecta ao banco de dados ERP para validar os IDs
                db_erp.connect()
                query_check = f"SELECT COUNT(*) FROM transa WHERE transacao IN ({placeholders})"
                count_existing = db_erp.fetch_one(query_check, tuple(novos_tipos_list))[0]
                db_erp.disconnect() # Desconecta após a validação

                if count_existing != len(novos_tipos_list):
                    mensagem = "Erro: Alguns IDs de transação selecionados não existem na tabela 'transa'. Por favor, verifique."
                    mensagem_tipo = "error"
                    # Mantém os tipos inválidos na lista para o usuário corrigir
                    tipos_transacao_permitidos_list = novos_tipos_list
                else:
                    # Converte a lista de IDs de volta para uma string separada por vírgula para salvar no DB
                    novos_tipos_str = ", ".join(novos_tipos_list)
                    # Atualiza a configuração no banco de dados SIGA_DB
                    success = db_siga.execute_query(
                        "UPDATE configuracoes SET valor_configuracao = %s, data_ultima_atualizacao = CURRENT_TIMESTAMP WHERE nome_configuracao = 'tipos_transacao_permitidos'",
                        (novos_tipos_str,)
                    )
                    if success:
                        mensagem = "Configuração salva com sucesso!"
                        mensagem_tipo = "success"
                        tipos_transacao_permitidos_list = novos_tipos_list # Atualiza o valor exibido
                    else:
                        mensagem = "Erro ao salvar a configuração."
                        mensagem_tipo = "error"
            else: # Se nenhuma transação foi selecionada (lista vazia)
                success = db_siga.execute_query(
                    "UPDATE configuracoes SET valor_configuracao = %s, data_ultima_atualizacao = CURRENT_TIMESTAMP WHERE nome_configuracao = 'tipos_transacao_permitidos'",
                    ('') # Salva uma string vazia no DB
                )
                if success:
                    mensagem = "Configuração de tipos de transação limpa com sucesso!"
                    mensagem_tipo = "success"
                    tipos_transacao_permitidos_list = [] # Limpa a lista exibida
                else:
                    mensagem = "Erro ao limpar a configuração."
                    mensagem_tipo = "error"

    except Exception as e:
        current_app.logger.error(f"Erro na página de configurações: {e}")
        mensagem = f"Ocorreu um erro inesperado: {e}"
        mensagem_tipo = "error"
    finally:
        db_siga.disconnect() # Garante que a conexão com o SIGA_DB seja fechada

    return render_template(
        'configuracoes.html',
        tipos_transacao_permitidos_list=tipos_transacao_permitidos_list, # Passa a lista
        transacoes_disponiveis=transacoes_disponiveis,
        mensagem=mensagem,
        mensagem_tipo=mensagem_tipo,
        datetime=datetime # Passa o objeto datetime para o template
    )

