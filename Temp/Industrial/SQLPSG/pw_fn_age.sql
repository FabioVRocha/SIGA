CREATE OR REPLACE FUNCTION pw_fn_age(p_data_fim timestamp, p_data_inicio timestamp)
RETURNS text AS
$$
BEGIN
  return age(p_data_fim, p_data_inicio);
END
$$ LANGUAGE plpgsql VOLATILE COST 100;

COMMENT ON FUNCTION pw_fn_age(p_data_fim timestamp, p_data_inicio timestamp) IS 'Retorna a diferença entre duas datas.';

ALTER FUNCTION pw_fn_age(timestamp, timestamp)
  OWNER TO postgres;