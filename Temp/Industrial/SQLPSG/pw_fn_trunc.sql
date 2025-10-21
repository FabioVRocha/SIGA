CREATE OR REPLACE FUNCTION pw_fn_trunc(p_valor numeric, p_casas_decimais integer)
RETURNS numeric AS
$$
BEGIN
  return trunc(p_valor, p_casas_decimais);
END
$$ LANGUAGE plpgsql VOLATILE COST 100;

COMMENT ON FUNCTION pw_fn_trunc(p_valor numeric, p_casas_decimais integer) IS 'Adiciona um valor informado em casas decimais após a vírgula em um valor.';

ALTER FUNCTION pw_fn_trunc(numeric, integer)
  OWNER TO postgres;