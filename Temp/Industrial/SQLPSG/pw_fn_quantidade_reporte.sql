-- Function: pw_fn_quantidade_reporte(integer)

-- DROP FUNCTION pw_fn_quantidade_reporte(integer);

CREATE OR REPLACE FUNCTION pw_fn_quantidade_reporte(pordem integer)
  RETURNS numeric AS
$BODY$
DECLARE
    qtde numeric;	
BEGIN
	select sum(PRIQUANTI) into qtde from toqmovi t where t.priordem = pordem and pritransac = 3;		
	RETURN coalesce(qtde,0);
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_quantidade_reporte(integer)
  OWNER TO postgres;
