-- Function: fn_custo_medio(character, numeric, date)

-- DROP FUNCTION fn_custo_medio(character, numeric, date);

CREATE OR REPLACE FUNCTION fn_custo_medio(pproduto character, pdeposito numeric, pdata date)
  RETURNS numeric AS
$BODY$
DECLARE
	vdata date;
	vcusto numeric(15,4);
	vmultiempresa char(1);
begin
	if (pdata is not null) and (pdata <> '0001-01-01') then
		vdata = pdata ;
	else	
		vdata := (select(coalesce((select ptodata from positoq order by ptodata desc limit 1), '0001-01-01')));
	end if;
    vmultiempresa := (select(coalesce(( select dadmulemp from dadosemp order by dadempresa asc limit 1), 'N')));
    
    if vmultiempresa = 'S' then
		execute '(select coalesce(po.psicusdep, 0)
			from possali1 po
			where po.psidata = ''' || vdata || '''' || '
			and po.produto = ''' || pproduto || '''' || '
			and (po.deposito = ' || pdeposito || ' OR ' || pdeposito || ' = 0))' into vcusto;
	else
		execute '(select coalesce(pm.psicusto, 0)
			from possalim pm
			where pm.psidata = ''' || vdata || '''' || '
			and pm.produto = ''' || pproduto || ''')' into vcusto;
	end if;

	return vcusto;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_custo_medio(character, numeric, date) SET search_path=public, pg_temp;

ALTER FUNCTION fn_custo_medio(character, numeric, date)
  OWNER TO postgres;
