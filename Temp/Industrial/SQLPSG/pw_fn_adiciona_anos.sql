CREATE OR REPLACE FUNCTION pw_fn_adiciona_anos(p_data date, p_qtde integer)
RETURNS date AS
$$
BEGIN
  return p_data::date + p_qtde * interval '1 year';
END
$$ LANGUAGE plpgsql VOLATILE COST 100;

COMMENT ON FUNCTION pw_fn_adiciona_anos(p_data date, p_qtde integer) IS 'Adiciona um valor em anos a uma data.';

ALTER FUNCTION pw_fn_adiciona_anos(date, integer)
  OWNER TO postgres;