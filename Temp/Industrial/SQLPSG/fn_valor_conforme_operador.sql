--drop function fn_valor_conforme_operador(boolean, char, numeric);
CREATE OR REPLACE FUNCTION fn_valor_conforme_operador(
    condicao BOOLEAN,
    operador CHAR,
    valor NUMERIC
) RETURNS NUMERIC AS $$
    SELECT CASE
        WHEN NOT condicao OR operador IS NULL THEN 0
        WHEN operador = '+' THEN valor
        WHEN operador = '-' THEN -valor
        ELSE 0 -- Valor default para operadores invalidos
    END;
$$ LANGUAGE sql IMMUTABLE;
ALTER FUNCTION fn_valor_conforme_operador(boolean, char, numeric) OWNER TO postgres;