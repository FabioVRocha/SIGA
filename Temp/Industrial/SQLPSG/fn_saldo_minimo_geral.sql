-- Function: fn_saldo_minimo_geral(character, character, character)

-- DROP FUNCTION fn_saldo_minimo_geral(character, character, character);

CREATE OR REPLACE FUNCTION fn_saldo_minimo_geral(pproduto character, pdeposito character, pmultiempresa character)
  RETURNS numeric AS
$BODY$
DECLARE
    vtpsaldo char(1);
    vdata date;
    vsaldo numeric(15,4);
    qtdmov numeric(15,4);
    deposito_array text;

begin
	if pdeposito = '' then
		deposito_array = '0';
	else
		deposito_array = pdeposito;
	end if;
    
	if pmultiempresa = 'S' then
	    execute 'select coalesce(sum(SLMINQTD),0) from prodminl p 
	        where p.slminprod = ''' || pproduto || '''' || ' and
	        p.slmindep = ANY(ARRAY[' || deposito_array || '])' into vsaldo;
   else
   		vsaldo := (select prosldmin from produto p where p.produto = pproduto);
   end If;

    return vsaldo;				
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_saldo_minimo_geral(character, character, character) SET search_path=public, pg_temp;

ALTER FUNCTION fn_saldo_minimo_geral(character, character, character)
  OWNER TO postgres;
