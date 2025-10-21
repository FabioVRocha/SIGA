-- Function: fn_ska_calculo_horas(numeric, numeric, character, numeric, date)

-- DROP FUNCTION fn_ska_calculo_horas(numeric, numeric, character, numeric, date);

CREATE OR REPLACE FUNCTION fn_ska_calculo_horas(primeiro_valor numeric, segundo_valor numeric, operacao character, retorno numeric, p_datainicio date)
  RETURNS numeric AS
$BODY$
DECLARE
  retorno numeric(11,6);
  vprimeiro_Minutos numeric(12,4);
  vsegundo_Minutos numeric(12,4);
  vsoma numeric(12,4);
  vresto numeric(11,6);
  vinteiro numeric(11,6);
  vdatainicio date; 
begin
	--raise notice 'Acessou função de cálculo';
	vdatainicio = p_datainicio;

	vprimeiro_Minutos = (trunc(primeiro_Valor,0) * 60 + ( (primeiro_Valor - trunc(primeiro_Valor,0)) *
100 ));
	vsegundo_Minutos = (trunc(segundo_Valor,0) * 60 + ( (segundo_Valor - trunc(segundo_Valor,0)) * 100
));

	IF (operacao = '-') THEN
	    vsoma = vprimeiro_Minutos - vsegundo_Minutos;
	    if vsoma < 0 then	    	
	    	vdatainicio = vdatainicio - interval '1 day';
	    	vsoma = ((23*60)+60) + vsoma;	    
	    end if;
	ELSE
	    vsoma = vprimeiro_Minutos + vsegundo_Minutos;	
	END IF;

	

    vinteiro = trunc((vsoma / 60 ),0);
	vresto = ( vsoma - (vinteiro * 60 ) ) / 100;

	retorno = vinteiro + vresto;
	p_datainicio = vdatainicio;

	RETURN retorno;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_ska_calculo_horas(numeric, numeric, character, numeric, date) SET search_path=public, pg_temp;

ALTER FUNCTION fn_ska_calculo_horas(numeric, numeric, character, numeric, date)
  OWNER TO postgres;
