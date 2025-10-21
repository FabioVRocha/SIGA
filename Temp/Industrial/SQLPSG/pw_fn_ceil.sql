CREATE OR REPLACE FUNCTION pw_fn_ceil(p_valor numeric)
RETURNS numeric AS
$BODY$
BEGIN
    return ceil(p_valor);
END
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

COMMENT ON FUNCTION pw_fn_ceil(p_valor numeric)
IS 'Arredondar o número para cima (ex.: 1.1 retorna 2).';

ALTER FUNCTION pw_fn_ceil(numeric)
  OWNER TO postgres;