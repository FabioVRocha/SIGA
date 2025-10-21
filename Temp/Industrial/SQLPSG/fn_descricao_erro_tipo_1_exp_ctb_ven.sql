--drop function fn_descricao_erro_tipo_1_exp_ctb_ven(int2, int2, int2, bpchar, date, bpchar, bpchar, int2, int8, int2)
CREATE OR REPLACE FUNCTION fn_descricao_erro_tipo_1_exp_ctb_ven(
    grupoItem int2,
    subgrupoItem int2,
    intdcod int2,
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
    cx text;
BEGIN
    -- Linha inicial com 88 espacos
    linha := '1-' || repeat(' ', 88);

    -- Grupo/Subgrupo
    IF COALESCE(subgrupoItem, 0) > 0 THEN
        cx := ltrim(to_char(subgrupoItem, 'FM999')) || '   ';
        cx := substring(cx from 1 for 3);
    ELSE
        cx := '   ';
    END IF;
    insert_text := lpad(to_char(COALESCE(grupoItem, 0), 'FM999'), 3, ' ') || '/' || cx;
    posicao := 5;
    linha := overlay(linha placing insert_text from posicao);

    -- intdcod
    insert_text := lpad(to_char(COALESCE(intdcod, 0), 'FM9999'), 4, ' ');
    posicao := 15;
    linha := overlay(linha placing insert_text from posicao);

    -- Docto
    insert_text := rpad(COALESCE(doctoItem::text, ''), 10, ' ');
    posicao := 22;
    linha := overlay(linha placing insert_text from posicao);

    -- Data
    insert_text := COALESCE(to_char(dataItem, 'DD/MM/YY'), '        ');
    posicao := 32;
    linha := overlay(linha placing insert_text from posicao);

    -- Produto
    insert_text := rpad(COALESCE(produtoItem, ''), 18, ' ');
    posicao := 43;
    linha := overlay(linha placing insert_text from posicao);

    -- Operacao / Deposito
    insert_text := rtrim(COALESCE(operacaoItem, '')) || '/' || lpad(COALESCE(depositoItem, 0)::text, 2, ' ');
    posicao := 61;
    linha := overlay(linha placing insert_text from posicao);

    -- Controle
    insert_text := lpad(COALESCE(controleItem, 0)::text, 10, ' ');
    posicao := 74;
    linha := overlay(linha placing insert_text from posicao);

    -- Sequencia
    insert_text := lpad(COALESCE(sequenciaItem, 0)::text, 3, ' ');
    posicao := 85;
    linha := overlay(linha placing insert_text from posicao);

    RETURN linha;
END;
$$ LANGUAGE plpgsql;
ALTER FUNCTION fn_descricao_erro_tipo_1_exp_ctb_ven(int2, int2, int2, bpchar, date, bpchar, bpchar, int2, int8, int2) OWNER TO postgres;