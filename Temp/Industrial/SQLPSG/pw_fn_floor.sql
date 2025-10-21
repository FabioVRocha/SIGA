CREATE OR REPLACE FUNCTION pw_fn_floor(p_valor numeric)
RETURNS numeric AS
$BODY$
BEGIN
    return floor(p_valor);
END
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

COMMENT ON FUNCTION pw_fn_floor(p_valor numeric)
IS 'Arredondar o número para baixo (ex.: 1.1 retorna 1).';

ALTER FUNCTION pw_fn_floor(numeric)
  OWNER TO postgres;