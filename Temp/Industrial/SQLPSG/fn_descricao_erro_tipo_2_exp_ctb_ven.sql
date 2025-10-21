--drop function fn_descricao_erro_tipo_2_exp_ctb_ven(bpchar, date, bpchar, bpchar, int2, int8, int2)

CREATE OR REPLACE FUNCTION fn_descricao_erro_tipo_2_exp_ctb_ven(
    doctoItem bpchar,
    dataItem date,
    produtoItem bpchar,
    operacaoItem bpchar,
    depositoItem int2,
    controleItem int8,
    sequenciaItem int2
)
RETURNS text AS $$
DECLARE
    linha text;
    posicao integer;
    
    insert_text text;
BEGIN
    -- Monta a linha inicial com 88 espacos
    linha := '2-' || repeat(' ', 88);

    -- Insere campos na linha, respeitando posicoes e comprimentos
    posicao := 22;
    insert_text := rpad(doctoItem::text, 9, ' ');
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 32;
    insert_text := to_char(dataItem, 'DD/MM/YY');
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 43;
    insert_text := produtoItem;
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 61;
    insert_text := operacaoItem || '/' || lpad(depositoItem::text, 2, ' ');
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 74;
    insert_text := lpad(controleItem::text, 10, ' '); 
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    posicao := 85;
    insert_text := lpad(sequenciaItem::text, 3, ' '); 
    linha := substring(linha FROM 1 FOR (posicao - 1)) || insert_text || substring(linha FROM (posicao + length(insert_text)));

    RETURN linha;
END;
$$ LANGUAGE plpgsql;
ALTER FUNCTION fn_descricao_erro_tipo_2_exp_ctb_ven(bpchar, date, bpchar, bpchar, int2, int8, int2) OWNER TO postgres;
