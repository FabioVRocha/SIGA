def fetch_order_details(pedido_code):
    """
    Recupera os detalhes de um pedido específico (cabeçalho e itens) a partir do ERP.
    Retorna uma tupla (dados, erro), em que erro é um dicionário com 'message' e 'status'.
    """
    pedido_value = (pedido_code or '').strip()
    if not pedido_value:
        return None, {'message': 'Pedido inválido.', 'status': 400}

    conn = get_erp_db_connection()
    if not conn:
        return None, {'message': 'Não foi possível conectar ao banco de dados do ERP.', 'status': 500}

    has_lcapecod_column = False
    column_check_cursor = None

    try:
        column_check_cursor = conn.cursor()
        column_check_cursor.execute(
            """
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_name = 'pedido'
                  AND column_name = 'lcapecod'
            )
            """
        )
        result = column_check_cursor.fetchone()
        if result:
            has_lcapecod_column = bool(result[0])
    except Error as e:
        print(f"Erro ao verificar a coluna 'lcapecod' na tabela 'pedido' (detalhes): {e}")
    finally:
        if column_check_cursor:
            column_check_cursor.close()

    try:
        cur = conn.cursor()

        load_lot_select = (
            "CAST(p.lcapecod AS TEXT) AS load_lot_code,\n                COALESCE(lc.lcades, '') AS load_lot_description"
            if has_lcapecod_column
            else "NULL AS load_lot_code,\n                '' AS load_lot_description"
        )
        load_lot_join = "LEFT JOIN lotecar lc ON p.lcapecod = lc.lcacod" if has_lcapecod_column else ""

        header_query = f"""
            WITH production_lots AS (
                SELECT
                    CAST(lots.pedido AS TEXT) AS pedido,
                    STRING_AGG(lots.lot_display, '; ' ORDER BY lots.lot_display) AS production_lots_display
                FROM (
                    SELECT DISTINCT
                        ao.acaopedi AS pedido,
                        CASE
                            WHEN COALESCE(lp.lotcod::text, '') <> '' THEN
                                lp.lotcod::text ||
                                CASE
                                    WHEN COALESCE(lp.lotdes, '') <> '' THEN ' - ' || lp.lotdes
                                    ELSE ''
                                END
                            ELSE ''
                        END AS lot_display
                    FROM acaorde2 ao
                    JOIN ordem o ON o.ordem = ao.acaoorde
                    LEFT JOIN loteprod lp ON lp.lotcod = o.lotcod
                    WHERE CAST(ao.acaopedi AS TEXT) = %s
                ) lots
                WHERE lots.lot_display <> ''
                GROUP BY lots.pedido
            )
            SELECT
                CAST(p.pedido AS TEXT) AS pedido,
                p.peddata,
                COALESCE(e.empnome, '') AS cliente,
                CASE
                    WHEN COALESCE(c.cidnome, '') <> '' THEN c.cidnome
                    WHEN COALESCE(p.pedentcid::text, '') <> '' THEN p.pedentcid::text
                    ELSE ''
                END AS cidade,
                CASE
                    WHEN COALESCE(c.estado, '') <> '' THEN c.estado
                    WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text
                    ELSE ''
                END AS estado,
                COALESCE(pl.production_lots_display, '') AS production_lots_display,
                COALESCE(rc.rgcdes, '') AS rgcdes,
                {load_lot_select}
            FROM pedido p
            LEFT JOIN empresa e ON p.pedcliente = e.empresa
            LEFT JOIN cidade c ON p.pedentcid = c.cidade
            LEFT JOIN regcar rc ON c.rgccicod = rc.rgccod
            LEFT JOIN production_lots pl ON pl.pedido = CAST(p.pedido AS TEXT)
            {load_lot_join}
            WHERE CAST(p.pedido AS TEXT) = %s
        """

        cur.execute(header_query, (pedido_value, pedido_value))
        header_row = cur.fetchone()
        cur.close()

        if not header_row:
            return None, {'message': 'Pedido não encontrado.', 'status': 404}

        (
            pedido,
            peddata,
            cliente,
            cidade,
            estado,
            production_lots_display,
            rgcdes_value,
            load_lot_code,
            load_lot_description,
        ) = header_row

        header_data = {
            'pedido': pedido or '',
            'cliente': cliente or '',
            'cidade': cidade or '',
            'uf': estado or '',
            'data_pedido': '',
            'lote_producao': production_lots_display or '',
            'lote_carga': '',
        }

        if isinstance(peddata, (datetime.date, datetime.datetime)):
            header_data['data_pedido'] = peddata.strftime('%d/%m/%Y')
        elif peddata:
            header_data['data_pedido'] = str(peddata)

        if load_lot_code:
            load_lot_str = str(load_lot_code)
            if load_lot_description:
                load_lot_str = f"{load_lot_str} - {load_lot_description}"
            header_data['lote_carga'] = load_lot_str

        details = {'header': header_data, 'items': []}

        # Agora recupera os itens a partir de pedprodu agregando os valores necessários
        # e trazendo também o nome do grupo/produto para calcular o % de frete
        items_query = """
            SELECT
                COALESCE(pp.pprproduto::text, '') AS codigo_produto,
                COALESCE(pp.pprseq::text, '') AS sequencia,
                COALESCE(prod.pronome::text, '') AS produto_nome,
                COALESCE(g.grunome, '') AS group_name,
                SUM(COALESCE(pp.pprquanti, 0)) AS quantidade_total,
                SUM(COALESCE(pp.pprlista, 0)) AS valor_tabela,
                AVG(COALESCE(pp.pprdesc1, 0)) AS percentual_desconto_avg,
                SUM(COALESCE(pp.pprvalor, 0)) AS valor_unitario_sum,
                SUM(COALESCE(pp.pprvlipi, 0)) AS valor_ipi_sum,
                SUM(COALESCE(pp.pprvlsoma, 0)) AS soma_vlsoma,
                SUM(COALESCE(pp.pprdescped, 0)) AS soma_descped
            FROM pedprodu pp
            LEFT JOIN produto prod ON prod.produto = pp.pprproduto
            LEFT JOIN grupo g ON prod.grupo = g.grupo
            WHERE CAST(pp.pedido AS TEXT) = %s
            GROUP BY 1,2,3,4
            ORDER BY 2,1
        """

        items_cur = conn.cursor()
        items_cur.execute(items_query, (pedido_value,))
        item_rows = items_cur.fetchall()
        items_cur.close()

        rgcdes = rgcdes_value if rgcdes_value else ''
        regcar_data = parse_regcar_description(rgcdes)

        for item_row in item_rows:
            (
                codigo_produto,
                sequencia,
                produto_nome,
                group_name,
                quantidade_total_raw,
                valor_tabela_raw,
                percentual_desconto_raw,
                valor_unitario_raw,
                valor_ipi_raw,
                soma_vlsoma_raw,
                soma_descped_raw,
            ) = item_row

            try:
                quantidade_total = float(quantidade_total_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                quantidade_total = 0.0

            try:
                valor_tabela = float(valor_tabela_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                valor_tabela = 0.0

            try:
                percentual_desconto = float(percentual_desconto_raw or 0) * 100.0
            except (TypeError, ValueError, InvalidOperation):
                percentual_desconto = 0.0

            try:
                valor_unitario_total = float(valor_unitario_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                valor_unitario_total = 0.0

            try:
                valor_ipi = float(valor_ipi_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                valor_ipi = 0.0

            try:
                soma_vlsoma = float(soma_vlsoma_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                soma_vlsoma = 0.0

            try:
                soma_descped = float(soma_descped_raw or 0)
            except (TypeError, ValueError, InvalidOperation):
                soma_descped = 0.0

            valor_total = soma_vlsoma - soma_descped

            product_line = get_product_line(group_name)
            product_ref = (produto_nome or '')[:2]

            freight_pct_decimal = calculate_freight_percentage(product_line, product_ref, regcar_data)
            percentual_frete = freight_pct_decimal * 100.0
            valor_frete = valor_total * freight_pct_decimal

            details['items'].append({
                'codigo_produto': codigo_produto or '',
                'sequencia': sequencia or '',
                'produto': produto_nome or '',
                'quantidade_total': quantidade_total,
                'valor_tabela': valor_tabela,
                'percentual_desconto': percentual_desconto,
                'valor_unitario_total': valor_unitario_total,
                'valor_ipi': valor_ipi,
                'percentual_frete': percentual_frete,
                'valor_frete': valor_frete,
                'valor_total': valor_total,
            })

        return details, None

    except Error as e:
        print(f"Erro ao carregar detalhes do pedido {pedido_value}: {e}")
        return None, {'message': 'Erro ao carregar detalhes do pedido.', 'status': 500}
    finally:
        if conn:
            conn.close()