# siga_erp/routes/relatorios.py

from flask import Blueprint, render_template, request, current_app, redirect, url_for
from datetime import datetime, date # Importa date também para manipulação de datas

# Cria um Blueprint para as rotas de relatórios
relatorios_bp = Blueprint('relatorios', __name__)

# Mapeamento das "Linhas" para os padrões de grunome para o filtro
LINHA_MAPPING = {
    "MADRESILVA": ["%MADRESILVA%", "%* M.%"],
    "PETRA": ["%PETRA%", "%* P.%"],
    "GARLAND": ["%GARLAND%", "%* G.%"],
    "GLASSMADRE": ["%GLASS%", "%* V.%"],
    "CAVILHAS": ["%CAVILHAS%"],
    "SOLARE": ["%SOLARE%", "%* S.%"],
    "ESPUMA": ["%* ESPUMA%"],
    "OUTROS": [] # "OUTROS" significa que não aplicamos um filtro específico de linha
}

@relatorios_bp.route('/espelho_notas', methods=['GET', 'POST'])
def espelho_notas():
    """
    Rota para o relatório de Espelho de Notas Fiscais Faturadas.
    Permite filtrar por período de data, nome do cliente/fornecedor e lote de carga.
    Respeita as configurações de tipos de transação permitidos do siga_db.
    Os campos de data inicial e final são preenchidos por padrão com a data atual.
    Inclui filtro por número do lote de carga com exibição da descrição.
    Adiciona filtro por "Linha" de produto.
    Exibe somas de Cubagem, Peso Bruto, Volumes, Quantidade, Valor do Frete e Valor Total.
    """
    # Acessa as instâncias de DBManager do objeto app
    db_erp = current_app.db_erp
    db_siga = current_app.db_siga

    notas = []
    total_notas = 0
    # Variáveis para as somas
    soma_cubagem = 0.0
    soma_peso_bruto = 0.0
    soma_volumes = 0
    soma_quantidade = 0.0
    soma_valor_frete = 0.0
    soma_valor_total = 0.0

    page = request.args.get('page', 1, type=int)
    per_page = 10 # Número de itens por página

    # Parâmetros de filtro
    data_inicial_str = request.form.get('data_inicial')
    data_final_str = request.form.get('data_final')
    nome_cliente = request.form.get('nome_cliente')
    lote_carga = request.form.get('lote_carga')
    filtro_linha = request.form.get('filtro_linha')
    descricao_lote_carga = ''

    # Se a requisição for GET e os campos de data/filtros não foram passados na URL,
    # define-os para a data atual ou vazio. Se foram passados na URL, usa-os.
    # Se for POST, os valores já virão do request.form.
    if request.method == 'GET':
        if not data_inicial_str:
            data_inicial_str = request.args.get('data_inicial', date.today().strftime('%Y-%m-%d'))
        if not data_final_str:
            data_final_str = request.args.get('data_final', date.today().strftime('%Y-%m-%d'))
        if not nome_cliente:
            nome_cliente = request.args.get('nome_cliente', '')
        if not lote_carga:
            lote_carga = request.args.get('lote_carga', '')
        if not filtro_linha:
            filtro_linha = request.args.get('filtro_linha', 'TODOS') # Valor padrão "TODOS" para o filtro de linha
    
    # Certifica-se de que os valores são strings para serem passados para o template
    data_inicial_str = data_inicial_str if data_inicial_str else ''
    data_final_str = data_final_str if data_final_str else ''
    nome_cliente = nome_cliente if nome_cliente else ''
    lote_carga = lote_carga if lote_carga else ''
    filtro_linha = filtro_linha if filtro_linha else 'TODOS'


    try:
        # Conecta ao banco de dados SIGA_DB para buscar a configuração
        db_siga.connect()
        tipos_transacao_permitidos_config = db_siga.fetch_one("SELECT valor_configuracao FROM configuracoes WHERE nome_configuracao = 'tipos_transacao_permitidos'")
        permitidos_list = []
        if tipos_transacao_permitidos_config and tipos_transacao_permitidos_config[0]:
            permitidos_list = [t.strip() for t in tipos_transacao_permitidos_config[0].split(',') if t.strip()]
        db_siga.disconnect()

        # Conecta ao banco de dados ERP para as operações de relatório e busca de descrição do lote
        db_erp.connect()

        # Busca a descrição do lote de carga se o número do lote for fornecido
        if lote_carga:
            lote_desc_query = "SELECT lcades FROM lotecar WHERE lcacod = %s"
            lote_desc_result = db_erp.fetch_one(lote_desc_query, (lote_carga,))
            if lote_desc_result:
                descricao_lote_carga = lote_desc_result[0]

        # Constrói a consulta SQL base para os dados das notas
        perc_frete_case = (
            "CASE "
            "WHEN g.grunome ILIKE '%MADRESILVA%' THEN CAST(SUBSTRING(rc.rgcdes FROM 'M([^;]+)') AS NUMERIC) "
            "WHEN g.grunome ILIKE '%PETRA%' THEN CAST(SUBSTRING(rc.rgcdes FROM 'P([^;]+)') AS NUMERIC) "
            "WHEN g.grunome ILIKE '%SOLARE%' THEN CAST(SUBSTRING(rc.rgcdes FROM 'S([^;]+)') AS NUMERIC) "
            "WHEN g.grunome ILIKE '%GLASS%' THEN CAST(SUBSTRING(rc.rgcdes FROM 'V([^;]+)') AS NUMERIC) "
            "WHEN g.grunome ILIKE '%GARLAND%' AND p.ref IN ('SF','NM','RC','CH') THEN CAST(SUBSTRING(rc.rgcdes FROM 'G([^;]+)') AS NUMERIC) "
            "WHEN g.grunome ILIKE '%GARLAND%' AND p.ref IN ('PF','PT','AL','MA','MC') THEN CAST(SUBSTRING(rc.rgcdes FROM '#([^;]+)') AS NUMERIC) "
            "ELSE NULL END"
        )

        perc_subquery = f"""
            SELECT
                tm.itecontrol AS controle,
                COALESCE(MAX({perc_frete_case}), 0) AS perc_frete
            FROM toqmovi tm
            LEFT JOIN produto p ON tm.priproduto = p.produto
            LEFT JOIN grupo g ON p.grupo = g.grupo
            LEFT JOIN regcar rc ON tm.rgccod = rc.rgccod
            GROUP BY tm.itecontrol
        """

        query_base = f"""
            SELECT
                d.notdocto, d.notserie, d.notdata, d.notclifor, e.empnome,
                d.notvltotal, d.notvlprod, d.notvlicms, d.notvlipi,
                d.notvlfrete, d.notvlsegur, d.notvldesco, d.notobsfisc, d.notstatus,
                COALESCE(perc.perc_frete, 0) AS perc_frete,
                d.notvlprod * COALESCE(perc.perc_frete, 0) / 100.0 AS valor_frete_calc
            FROM
                doctos d
            JOIN
                empresa e ON d.notclifor = e.empresa
            LEFT JOIN
                toqmovi tm ON d.controle = tm.itecontrol
            LEFT JOIN
                ({perc_subquery}) perc ON perc.controle = d.controle
            LEFT JOIN
                opera o ON tm.operacao = o.operacao
            LEFT JOIN
                transa t ON o.opetransac = t.transacao
            LEFT JOIN
                lotecar lc ON d.vollcacod = lc.lcacod
            LEFT JOIN
                produto p ON tm.priproduto = p.produto
            LEFT JOIN
                grupo g ON p.grupo = g.grupo
            WHERE 1=1
        """
        count_query_base = f"""
            SELECT
                COUNT(DISTINCT d.controle)
            FROM
                doctos d
            JOIN
                empresa e ON d.notclifor = e.empresa
            LEFT JOIN
                toqmovi tm ON d.controle = tm.itecontrol
            LEFT JOIN
                ({perc_subquery}) perc ON perc.controle = d.controle
            LEFT JOIN
                opera o ON tm.operacao = o.operacao
            LEFT JOIN
                transa t ON o.opetransac = t.transacao
            LEFT JOIN
                lotecar lc ON d.vollcacod = lc.lcacod
            LEFT JOIN
                produto p ON tm.priproduto = p.produto
            LEFT JOIN
                grupo g ON p.grupo = g.grupo
            WHERE 1=1
        """

        # NOVO: Consulta SQL base para as somas
        summary_query_base = f"""
            SELECT
                SUM(d.notvltotal) AS total_geral,
                SUM(d.notvlprod * COALESCE(perc.perc_frete, 0) / 100.0) AS total_frete,
                SUM(d.volquanti) AS total_volumes,
                SUM(d.volpesbru) AS total_peso_bruto,
                SUM(lc.lcam3) AS total_cubagem
            FROM
                doctos d
            JOIN
                empresa e ON d.notclifor = e.empresa
            LEFT JOIN
                toqmovi tm ON d.controle = tm.itecontrol
            LEFT JOIN
                ({perc_subquery}) perc ON perc.controle = d.controle
            LEFT JOIN
                opera o ON tm.operacao = o.operacao
            LEFT JOIN
                transa t ON o.opetransac = t.transacao
            LEFT JOIN
                lotecar lc ON d.vollcacod = lc.lcacod
            LEFT JOIN
                produto p ON tm.priproduto = p.produto
            LEFT JOIN
                grupo g ON p.grupo = g.grupo
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

        # Filtro por lote de carga
        if lote_carga:
            filter_clauses.append(" AND d.vollcacod = %s")
            params.append(lote_carga)

        # Aplica o filtro de "Linha"
        if filtro_linha and filtro_linha != "TODOS" and filtro_linha in LINHA_MAPPING:
            line_patterns = LINHA_MAPPING[filtro_linha]
            if line_patterns:
                line_conditions = []
                for pattern in line_patterns:
                    line_conditions.append("g.grunome ILIKE %s")
                    params.append(pattern)
                filter_clauses.append(f" AND ({' OR '.join(line_conditions)})")
            elif filtro_linha == "OUTROS":
                all_defined_patterns = []
                for key, patterns in LINHA_MAPPING.items():
                    if key != "OUTROS":
                        all_defined_patterns.extend(patterns)
                
                if all_defined_patterns:
                    not_in_conditions = []
                    for pattern in all_defined_patterns:
                        not_in_conditions.append("g.grunome NOT ILIKE %s")
                        params.append(pattern)
                    filter_clauses.append(f" AND ({' AND '.join(not_in_conditions)} OR g.grunome IS NULL)")

        # Aplica o filtro de tipos de transação permitidos da configuração
        if permitidos_list:
            placeholders = ', '.join(['%s'] * len(permitidos_list))
            filter_clauses.append(f" AND t.transacao IN ({placeholders})")
            params.extend(permitidos_list)


        # Constrói a consulta final para os dados das notas
        full_query = query_base + " ".join(filter_clauses) + " GROUP BY d.controle, d.notdocto, d.notserie, d.notdata, d.notclifor, e.empnome, d.notvltotal, d.notvlprod, d.notvlicms, d.notvlipi, d.notvlfrete, d.notvlsegur, d.notvldesco, d.notobsfisc, d.notstatus ORDER BY d.notdata DESC, d.notdocto DESC"
        full_count_query = count_query_base + " ".join(filter_clauses)
        
        # Constrói a consulta final para as somas
        full_summary_query = summary_query_base + " ".join(filter_clauses)

        # Busca o total de notas para paginação
        total_notas_result = db_erp.fetch_one(full_count_query, params)
        total_notas = total_notas_result[0] if total_notas_result else 0

        # Adiciona a cláusula LIMIT e OFFSET para paginação na consulta principal
        offset = (page - 1) * per_page
        full_query += " LIMIT %s OFFSET %s"
        params_paginated = params + [per_page, offset] # Cria uma nova lista de params para a query paginada

        # Busca as notas fiscais
        raw_notas = db_erp.fetch_all(full_query, params_paginated)

        # Mapeia os resultados para um formato mais legível no template
        column_names = [
            'notdocto', 'notserie', 'notdata', 'notclifor', 'empnome',
            'notvltotal', 'notvlprod', 'notvlicms', 'notvlipi',
            'notvlfrete', 'notvlsegur', 'notvldesco', 'notobsfisc', 'notstatus',
            'perc_frete', 'valor_frete_calc'
        ]
        notas = [dict(zip(column_names, row)) for row in raw_notas]

        # NOVO: Busca as somas dos campos
        summary_result = db_erp.fetch_one(full_summary_query, params)
        if summary_result:
            soma_valor_total = summary_result[0] if summary_result[0] is not None else 0.0
            soma_valor_frete = summary_result[1] if summary_result[1] is not None else 0.0
            soma_volumes = summary_result[2] if summary_result[2] is not None else 0
            soma_peso_bruto = summary_result[3] if summary_result[3] is not None else 0.0
            soma_cubagem = summary_result[4] if summary_result[4] is not None else 0.0
            # A quantidade é a soma dos volumes (volquanti)
            soma_quantidade = soma_volumes # Renomeando para clareza no template

    except Exception as e:
        current_app.logger.error(f"Erro ao buscar espelho de notas: {e}")
    finally:
        db_erp.disconnect() # Garante que a conexão com o ERP seja fechada

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
        lote_carga=lote_carga,
        descricao_lote_carga=descricao_lote_carga,
        filtro_linha=filtro_linha,
        linhas_disponiveis=sorted(LINHA_MAPPING.keys()),
        # NOVO: Passa os valores somados para o template
        soma_cubagem=soma_cubagem,
        soma_peso_bruto=soma_peso_bruto,
        soma_volumes=soma_volumes, # Mantido como volumes para consistência com o campo
        soma_quantidade=soma_quantidade, # Usando soma_volumes como soma_quantidade
        soma_valor_frete=soma_valor_frete,
        soma_valor_total=soma_valor_total,
        datetime=datetime # Passa o objeto datetime para o template
    )
# new route for regcar percent
@relatorios_bp.route('/regcar_percent', methods=['GET'])
def regcar_percent():
    """Exibe os percentuais de frete da tabela regcar."""
    db_erp = current_app.db_erp
    regcar_data = []
    try:
        db_erp.connect()
        query = """
            SELECT
                rgccod,
                rgcdes,
                CAST(SUBSTRING(rgcdes FROM 'P([^;]+)') AS NUMERIC) AS p,
                CAST(SUBSTRING(rgcdes FROM 'M([^;]+)') AS NUMERIC) AS m,
                CAST(SUBSTRING(rgcdes FROM 'G([^;]+)') AS NUMERIC) AS g,
                CAST(SUBSTRING(rgcdes FROM '#([^;]+)') AS NUMERIC) AS hash,
                CAST(SUBSTRING(rgcdes FROM 'V([^;]+)') AS NUMERIC) AS v,
                CAST(SUBSTRING(rgcdes FROM 'S([^;]+)') AS NUMERIC) AS s,
                CAST(SUBSTRING(rgcdes FROM '\\$([^;]+)') AS NUMERIC) AS m3
            FROM regcar
            ORDER BY rgccod
        """
        rows = db_erp.fetch_all(query)
        column_names = ['rgccod', 'rgcdes', 'p', 'm', 'g', 'hash', 'v', 's', 'm3']
        regcar_data = [dict(zip(column_names, r)) for r in rows]
    except Exception as e:
        current_app.logger.error(f"Erro ao buscar dados de regcar: {e}")
    finally:
        db_erp.disconnect()

    return render_template('relatorios/regcar_percent.html', regcar_data=regcar_data, datetime=datetime)
