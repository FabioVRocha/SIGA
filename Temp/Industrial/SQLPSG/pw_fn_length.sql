CREATE OR REPLACE FUNCTION pw_fn_length(p_string text)
RETURNS integer AS
$BODY$
BEGIN
    return length(p_string);
END
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

COMMENT ON FUNCTION pw_fn_length(p_string text)
IS 'Faz a contagem de caracteres de um conteúdo e retorna o número total.';

ALTER FUNCTION pw_fn_length(text)
  OWNER TO postgres;