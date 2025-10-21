CREATE OR REPLACE FUNCTION pw_fn_upper(p_string text)
RETURNS text AS
$BODY$
BEGIN
    return upper(p_string);
END
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

COMMENT ON FUNCTION pw_fn_upper(p_string text)
IS 'Faz todas as letras do conteúdo ficarem maiúsculas.';

ALTER FUNCTION pw_fn_upper(text)
  OWNER TO postgres;