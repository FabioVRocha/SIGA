# siga_erp/routes/relatorios.py

from flask import Blueprint, render_template, request, current_app, redirect, url_for
from database import DBManager
from datetime import datetime # Importa o módulo datetime

# Cria um Blueprint para as rotas de relatórios
relatorios_bp = Blueprint('relatorios', __name__)

@relatorios_bp.route('/espelho_notas', methods=['GET', 'POST'])
def espelho_notas():
    """
    Rota para o relatório de Espelho de Notas Fiscais Faturadas.
    Permite filtrar por período de data e nome do cliente/fornecedor,
    e inclui paginação. Agora também permite filtrar por descrição da operação e nome da transação.
    """
    db = DBManager()
    notas = []
    total_notas = 0
    page = request.args.get('page', 1, type=int)
    per_page = 10 # Número de itens por página

    # Parâmetros de filtro
    data_inicial_str = request.form.get('data_inicial') if request.method == 'POST' else request.args.get('data_inicial', '')
    data_final_str = request.form.get('data_final') if request.method == 'POST' else request.args.get('data_final', '')
    nome_cliente = request.form.get('nome_cliente') if request.method == 'POST' else request.args.get('nome_cliente', '')
    # Novos parâmetros de filtro para opera e transa
    descricao_operacao = request.form.get('descricao_operacao') if request.method == 'POST' else request.args.get('descricao_operacao', '')
    nome_transacao = request.form.get('nome_transacao') if request.method == 'POST' else request.args.get('nome_transacao', '')

    try:
        db.connect()

        # Constrói a consulta SQL base com os novos JOINs
        query_base = """
            SELECT
                d.notdocto, d.notserie, d.notdata, d.notclifor, e.empnome,
                d.notvltotal, d.notvlprod, d.notvlicms, d.notvlipi,
                d.notvlfrete, d.notvlsegur, d.notvldesco, d.notobsfisc, d.notstatus
            FROM
                doctos d
            JOIN
                empresa e ON d.notclifor = e.empresa
            LEFT JOIN
                toqmovi tm ON d.controle = tm.itecontrol
            LEFT JOIN
                opera o ON tm.operacao = o.operacao
            LEFT JOIN
                transa t ON o.opetransac = t.transacao
            WHERE 1=1
        """
        count_query_base = """
            SELECT
                COUNT(DISTINCT d.controle) -- Conta documentos distintos para evitar duplicação por toqmovi
            FROM
                doctos d
            JOIN
                empresa e ON d.notclifor = e.empresa
            LEFT JOIN
                toqmovi tm ON d.controle = tm.itecontrol
            LEFT JOIN
                opera o ON tm.operacao = o.operacao
            LEFT JOIN
                transa t ON o.opetransac = t.transacao
            WHERE 1=1
        """

        params = []
        filter_clauses = []

        # Filtro por status ou valor total (para notas faturadas)
        filter_clauses.append(" AND (d.notstatus = 'F' OR d.notvltotal > 0)")

        # Filtro por período de data
        if data_inicial_str:
            try:
                data_inicial = datetime.strptime(data_inicial_str, '%Y-%m-%d').date()
                filter_clauses.append(" AND d.notdata >= %s")
                params.append(str(data_inicial))
            except ValueError:
                current_app.logger.warning(f"Formato de data inicial inválido: {data_inicial_str}")

        if data_final_str:
            try:
                data_final = datetime.strptime(data_final_str, '%Y-%m-%d').date()
                filter_clauses.append(" AND d.notdata <= %s")
                params.append(str(data_final))
            except ValueError:
                current_app.logger.warning(f"Formato de data final inválido: {data_final_str}")

        # Filtro por nome do cliente/fornecedor (busca parcial insensível a maiúsculas/minúsculas)
        if nome_cliente:
            filter_clauses.append(" AND e.empnome ILIKE %s")
            params.append(f"%{nome_cliente}%")

        # Novos filtros para opera e transa
        if descricao_operacao:
            filter_clauses.append(" AND o.opedescri ILIKE %s")
            params.append(f"%{descricao_operacao}%")

        if nome_transacao:
            filter_clauses.append(" AND t.trsname ILIKE %s")
            params.append(f"%{nome_transacao}%")

        # Constrói a consulta final com filtros
        # Usamos DISTINCT d.controle para garantir que cada nota fiscal apareça apenas uma vez
        # mesmo que haja múltiplos itens em toqmovi para a mesma nota.
        full_query = query_base + " ".join(filter_clauses) + " GROUP BY d.controle, d.notdocto, d.notserie, d.notdata, d.notclifor, e.empnome, d.notvltotal, d.notvlprod, d.notvlicms, d.notvlipi, d.notvlfrete, d.notvlsegur, d.notvldesco, d.notobsfisc, d.notstatus ORDER BY d.notdata DESC, d.notdocto DESC"
        full_count_query = count_query_base + " ".join(filter_clauses)

        # Busca o total de notas para paginação
        total_notas_result = db.fetch_one(full_count_query, params)
        total_notas = total_notas_result[0] if total_notas_result else 0

        # Adiciona a cláusula LIMIT e OFFSET para paginação
        offset = (page - 1) * per_page
        full_query += " LIMIT %s OFFSET %s"
        params.extend([per_page, offset])

        # Busca as notas fiscais
        raw_notas = db.fetch_all(full_query, params)

        # Mapeia os resultados para um formato mais legível no template
        column_names = [
            'notdocto', 'notserie', 'notdata', 'notclifor', 'empnome',
            'notvltotal', 'notvlprod', 'notvlicms', 'notvlipi',
            'notvlfrete', 'notvlsegur', 'notvldesco', 'notobsfisc', 'notstatus'
        ]
        notas = [dict(zip(column_names, row)) for row in raw_notas]

    except Exception as e:
        current_app.logger.error(f"Erro ao buscar espelho de notas: {e}")
        # Em um ambiente de produção, você pode redirecionar para uma página de erro
        # ou exibir uma mensagem amigável ao usuário.
    finally:
        db.disconnect()

    # Calcula o número total de páginas
    total_pages = (total_notas + per_page - 1) // per_page

    return render_template(
        'relatorios/espelho_notas.html',
        notas=notas,
        page=page,
        per_page=per_page,
        total_notas=total_notas,
        total_pages=total_pages,
        data_inicial=data_inicial_str,
        data_final=data_final_str,
        nome_cliente=nome_cliente,
        descricao_operacao=descricao_operacao, # Passa o novo parâmetro para o template
        nome_transacao=nome_transacao,       # Passa o novo parâmetro para o template
        datetime=datetime # Passa o objeto datetime para o template
    )