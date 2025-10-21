CREATE OR REPLACE FUNCTION pw_fn_adiciona_meses(p_data date, p_qtde integer)
RETURNS date AS
$$
BEGIN
  return p_data::date + p_qtde * interval '1 month';
END
$$ LANGUAGE plpgsql VOLATILE COST 100;

COMMENT ON FUNCTION pw_fn_adiciona_meses(p_data date, p_qtde integer) IS 'Adiciona um valor em meses a uma data.';

ALTER FUNCTION pw_fn_adiciona_meses(date, integer)
  OWNER TO postgres;