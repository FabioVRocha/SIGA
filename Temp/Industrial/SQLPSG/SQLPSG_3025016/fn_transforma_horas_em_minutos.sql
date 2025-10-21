-- Function: fn_transforma_horas_em_minutos(numeric)

-- DROP FUNCTION fn_transforma_horas_em_minutos(numeric);

CREATE OR REPLACE FUNCTION fn_transforma_horas_em_minutos(p_horas numeric)
  RETURNS numeric AS
$BODY$
DECLARE
    v_minutos numeric(12,4);
BEGIN 
    v_minutos = (trunc(p_horas) * 60 + ((p_horas - trunc(p_horas)) * 100));
    RETURN v_minutos;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_transforma_horas_em_minutos(numeric) SET search_path=public, pg_temp;

ALTER FUNCTION fn_transforma_horas_em_minutos(numeric)
  OWNER TO postgres;
