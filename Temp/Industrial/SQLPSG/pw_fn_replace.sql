CREATE OR REPLACE FUNCTION pw_fn_replace(p_string text, p_busca text, p_substitui text)
RETURNS text AS
$BODY$
BEGIN
    return replace(p_string, p_busca, p_substitui);
END
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

COMMENT ON FUNCTION pw_fn_replace(p_string text, p_busca text, p_substitui text)
IS 'Substitui uma parte de um conte�do, ou ele inteiro, por outro conte�do inteiro.';

ALTER FUNCTION pw_fn_replace(text, text, text)
  OWNER TO postgres;