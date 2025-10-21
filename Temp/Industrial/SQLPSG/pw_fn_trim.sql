CREATE OR REPLACE FUNCTION pw_fn_trim(p_string text)
RETURNS text AS
$BODY$
BEGIN
    return trim(p_string);
END
$BODY$
LANGUAGE plpgsql VOLATILE
COST 100;

COMMENT ON FUNCTION pw_fn_trim(p_string text)
IS 'Remove espaços em branco antes e depois de um conteúdo.';

ALTER FUNCTION pw_fn_trim(text)
  OWNER TO postgres;