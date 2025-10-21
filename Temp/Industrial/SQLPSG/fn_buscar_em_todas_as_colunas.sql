-- Function: fn_buscar_em_todas_as_colunas(text, text, text)

-- DROP FUNCTION fn_buscar_em_todas_as_colunas(text, text, text);

CREATE OR REPLACE FUNCTION fn_buscar_em_todas_as_colunas(IN p_schema text, IN p_tabela text, IN p_busca text)
  RETURNS TABLE(pk_val text, colunas_encontradas text, colunas_encontradas_array text[]) AS
$BODY$
DECLARE
    v_sql TEXT;
    v_pk_cols TEXT[];
    v_pk_expr TEXT;
BEGIN
    -- 1. Descobre todas as colunas da PK
    SELECT array_agg(a.attname ORDER BY a.attnum)
    INTO v_pk_cols
    FROM pg_index i
    JOIN pg_attribute a
      ON a.attrelid = i.indrelid
     AND a.attnum = ANY(i.indkey)
    WHERE i.indrelid = format('%I.%I', p_schema, p_tabela)::regclass
      AND i.indisprimary;

    IF v_pk_cols IS NULL THEN
        RAISE NOTICE 'Tabela %.% não possui PK, todas as colunas serão consideradas.', p_schema, p_tabela;
    
        -- 1.1. Se a tabela não tiver PK, utiliza todas as colunas como PK para facilitar encontrar o registro.
        SELECT array_agg(column_name::text ORDER BY ordinal_position)
        INTO v_pk_cols
        FROM information_schema.columns
        WHERE (table_schema, table_name) = (p_schema, p_tabela);
    END IF;

    -- 2. Concatena as colunas da PK em uma expressão de texto
    SELECT string_agg(format('''%s: '' || %I::text', col, col), ' || '', '' || ')
    INTO v_pk_expr
    FROM unnest(v_pk_cols) AS col;

    -- 3. Monta SQL dinâmico coluna a coluna
    SELECT 'SELECT pk_val, ' ||
           'string_agg(col_result, '' | '' ORDER BY col_result) AS colunas_encontradas, ' ||
           'array_agg(coluna) AS colunas_encontradas_array ' ||
           'FROM (' ||
           string_agg(
               format(
                   'SELECT %1$s AS pk_val, ' ||
                   'CASE WHEN %2$I::text ILIKE ''%%'' || %3$L || ''%%'' ' ||
                   'THEN %4$L || '': '' || %2$I::text ELSE NULL END AS col_result, ' ||
                   '%2$L::text as coluna ' ||
                   'FROM %5$I.%6$I',
                   v_pk_expr, column_name, p_busca, column_name, p_schema, p_tabela
               ),
               ' UNION ALL '
           ) ||
           ') t WHERE col_result IS NOT NULL ' ||
           'GROUP BY pk_val'
    INTO v_sql
    FROM information_schema.columns
    WHERE table_schema = p_schema
      AND table_name = p_tabela;

--    Raise notice '%s', v_sql;

    -- 4. Executa SQL
    RETURN QUERY EXECUTE v_sql;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION fn_buscar_em_todas_as_colunas(text, text, text)
  OWNER TO postgres;
