
CREATE OR REPLACE FUNCTION pw_fn_mod(p_dividendo numeric, p_divisor numeric)
RETURNS numeric AS
$$
BEGIN
  return mod(p_dividendo, p_divisor);
END
$$ LANGUAGE plpgsql VOLATILE COST 100;

COMMENT ON FUNCTION pw_fn_mod(p_dividendo numeric, p_divisor numeric) IS 'Retorna o resto da divisão do primeiro valor pelo segundo.';


ALTER FUNCTION pw_fn_mod(numeric, numeric)
  OWNER TO postgres;