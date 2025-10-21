CREATE OR REPLACE FUNCTION pw_fn_lower(p_string text)
RETURNS text AS
$BODY$
BEGIN
    return lower(p_string);
END
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

COMMENT ON FUNCTION pw_fn_lower(p_string text)
IS 'Faz todas as letras do conteúdo ficarem minúsculas.';

ALTER FUNCTION pw_fn_lower(text)
  OWNER TO postgres;