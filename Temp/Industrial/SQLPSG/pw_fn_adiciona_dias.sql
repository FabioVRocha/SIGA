CREATE OR REPLACE FUNCTION pw_fn_adiciona_dias(p_data date, p_qtde integer)
RETURNS date AS
$$
BEGIN
  return p_data::date + p_qtde * interval '1 day';
END
$$ LANGUAGE plpgsql VOLATILE COST 100;

COMMENT ON FUNCTION pw_fn_adiciona_dias(p_data date, p_qtde integer) IS 'Adiciona um valor em dias a uma data.';

ALTER FUNCTION pw_fn_adiciona_dias(date, integer)
  OWNER TO postgres;