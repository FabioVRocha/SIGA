--select fn_tranforma_horas_decimal(1.50)

CREATE OR REPLACE FUNCTION fn_tranforma_horas_decimal(primeiro_valor numeric)
  RETURNS numeric AS
$BODY$
DECLARE
  retorno numeric(11,6);
  hora numeric(12,4);
  vsegundo_Minutos numeric(12,4);
  vsoma numeric(12,4);
  vresto numeric(11,6);
  vinteiro numeric(11,6);
BEGIN
	hora = (trunc(primeiro_Valor,0));
	vresto = primeiro_Valor - (trunc(primeiro_Valor,0)) ;
	vresto = (vresto / 100) * 60;
	
	retorno = trunc(hora + vresto, 2);

	RETURN retorno;

END;
$BODY$
  LANGUAGE plpgsql
  COST 100;

ALTER FUNCTION fn_tranforma_horas_decimal(numeric)
  OWNER TO postgres;