--drop function fn_descricao_erro_tipo_3_exp_ctb_ven(bpchar, bpchar, int2, text, numeric(14, 2), int2, bpchar, date, bpchar, numeric(5), bpchar, numeric(10), numeric(3))
CREATE OR REPLACE FUNCTION fn_descricao_erro_tipo_3_exp_ctb_ven(
    centro_de_custo bpchar,
    plano_de_contas bpchar,
    codigo_historico int2,
    comphist text,
    valor numeric(14, 2),
    pri_transacao int2,
    debito_credito bpchar,
    data_lancamento date,
    docto bpchar,
    intmcod numeric(5),
    operacao bpchar,
    controle numeric(10),
    sequencia numeric(3)    
)
RETURNS text AS $$
DECLARE
    linha text := '';
    posicao integer;

    tem_centro_de_custo int := 0;
    tem_plano_de_contas int := 0;
    tem_historico int := 0;
    tem_historico_e_complemento int := 0;
    tem_valor_e_transacao int := 0;
    
    insert_text text;
BEGIN
    -- Verificação das tabelas
    SELECT 1 INTO tem_centro_de_custo
    FROM ccusto
    WHERE ccusto = centro_de_custo
    LIMIT 1;

    SELECT 1 INTO tem_plano_de_contas
    FROM planoc
    WHERE planoc = plano_de_contas
    LIMIT 1;

    SELECT CASE
        WHEN codigo_historico > 0
         AND COALESCE((SELECT 1 FROM hisctb WHERE historico = codigo_historico LIMIT 1), 0) = 0
        THEN NULL
        ELSE 1
    END
    INTO tem_historico;

    SELECT CASE
        WHEN (length(trim(comphist)) = 0 OR comphist IS NULL)
         AND (codigo_historico = 0 OR codigo_historico IS NULL)
        THEN NULL
        ELSE 1
    END
    INTO tem_historico_e_complemento;

    SELECT CASE
        WHEN valor < 0.005
         AND pri_transacao NOT IN (5, 15)
        THEN NULL
        ELSE 1
    END
    INTO tem_valor_e_transacao;

    -- Linha com espaços
    linha := '3-' || repeat(' ', 88);

    -- Inserções com proteção contra NULL
    posicao := 5;
    insert_text := COALESCE(debito_credito, '');
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 7;
    insert_text := CASE WHEN COALESCE(tem_centro_de_custo, 0) > 0 
                        THEN rpad(COALESCE(centro_de_custo, ''), 5, ' ') 
                        ELSE rpad('?' || COALESCE(centro_de_custo, ''), 5, ' ')
                   END;
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 13;
    insert_text := CASE WHEN COALESCE(tem_plano_de_contas, 0) > 0 
                        THEN rpad(COALESCE(plano_de_contas, ''), 15, ' ')
                        ELSE rpad('?' || COALESCE(plano_de_contas, ''), 15, ' ')
                   END;
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 29;
    insert_text := CASE WHEN codigo_historico > 0 
                        THEN CASE WHEN COALESCE(tem_historico, 0) = 0 
                                  THEN rpad('?' || codigo_historico::text, 4, ' ') 
                                  ELSE lpad(codigo_historico::text, 4, ' ') 
                             END
                        ELSE '    ' 
                   END;
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 31;
    insert_text := CASE WHEN COALESCE(tem_historico_e_complemento, 0) = 0 THEN '?' ELSE '' END;
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 34;
    insert_text := CASE WHEN COALESCE(tem_historico_e_complemento, 0) = 0 THEN '?' ELSE 'Ok' END;
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 37;
    insert_text := CASE WHEN COALESCE(tem_valor_e_transacao, 0) = 0 
                        THEN '? Valor ?' 
                        ELSE to_char(COALESCE(valor, 0), 'FM9999999999990.00')
                   END;
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 48;
    --insert_text := to_char(COALESCE(data_lancamento, CURRENT_DATE), 'DD/MM/YY');
    insert_text := CASE WHEN data_lancamento IS NULL THEN rpad('', 9, ' ') ELSE to_char(data_lancamento, 'DD/MM/YY') END;
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 57;
    insert_text := rpad(COALESCE(docto, ''), 9, ' ');
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 66;
    insert_text := rpad(COALESCE(intmcod::text, '0') || '\\' || COALESCE(operacao, ''), 11, ' ');
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 77;
    insert_text := lpad(COALESCE(controle::text, '0'), 10, ' ');
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 88;
    insert_text := lpad(COALESCE(sequencia::text, '0'), 3, ' ');     
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    RETURN COALESCE(substring(linha, 1, 90), '');
END;
$$ LANGUAGE plpgsql;
ALTER FUNCTION fn_descricao_erro_tipo_3_exp_ctb_ven(bpchar, bpchar, int2, text, numeric(14, 2), int2, bpchar, date, bpchar, numeric(5), bpchar, numeric(10), numeric(3)) OWNER TO postgres;