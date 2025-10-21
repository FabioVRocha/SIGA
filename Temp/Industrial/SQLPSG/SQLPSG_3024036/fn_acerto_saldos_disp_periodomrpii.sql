-- Function: fn_acerto_saldos_disp_periodomrpii(numeric, character, date, numeric, numeric)

-- DROP FUNCTION fn_acerto_saldos_disp_periodomrpii(numeric, character, date, numeric, numeric);

CREATE OR REPLACE FUNCTION fn_acerto_saldos_disp_periodomrpii(pplano numeric, pproduto character, pdata date, psaldo numeric, sldordem numeric)
  RETURNS void AS
$BODY$
declare
begin
	
	update planei_tmp --  planecii  Sergio - OS 4185124 - 28/10/24 
		set PLN2SLEXD = sldordem, 
		    PLN2SLDIN = psaldo
		where PLN2CODIG = pplano and 
		      PLN2PRODU = pproduto and 
			  PLN2DTPER = pdata;	
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_acerto_saldos_disp_periodomrpii(numeric, character, date, numeric, numeric) SET search_path=public, pg_temp;

ALTER FUNCTION fn_acerto_saldos_disp_periodomrpii(numeric, character, date, numeric, numeric)
  OWNER TO postgres;
