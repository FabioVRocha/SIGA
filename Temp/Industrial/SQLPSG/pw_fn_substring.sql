CREATE OR REPLACE FUNCTION pw_fn_substring(p_string text, p_inicio integer, p_qtd integer)
RETURNS text AS
$BODY$
BEGIN
    return substr(p_string, p_inicio, p_qtd);
END
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

COMMENT ON FUNCTION pw_fn_substring(p_string text, p_inicio integer, p_qtd integer)
IS 'Recorta parte de um conteúdo.';

ALTER FUNCTION pw_fn_substring(text, integer, integer)
  OWNER TO postgres;