CREATE OR REPLACE FUNCTION pw_fn_current_date()
RETURNS date AS
$$
BEGIN
  return current_date;
END
$$ LANGUAGE plpgsql VOLATILE COST 100;

COMMENT ON FUNCTION pw_fn_current_date() IS 'Retorna a data atual.';

ALTER FUNCTION pw_fn_current_date()
  OWNER TO postgres;