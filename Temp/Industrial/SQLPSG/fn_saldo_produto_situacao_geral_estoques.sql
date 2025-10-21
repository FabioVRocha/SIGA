-- Function: fn_saldo_produto_situacao_geral_estoques(date, character, character, numeric, numeric)

-- DROP FUNCTION fn_saldo_produto_situacao_geral_estoques(date, character, character, numeric, numeric);

CREATE OR REPLACE FUNCTION fn_saldo_produto_situacao_geral_estoques(pdata date, pproduto character, pdeposito character, pcontrole numeric, psequencia numeric)
  RETURNS numeric AS
$BODY$
DECLARE
	vtpsaldo char(1);
	vdata date;
	vsaldo numeric(15,4);
	qtdmov numeric(15,4);
	deposito_array text;
	vdataatual date;
	vdataanterior date;

BEGIN
	if pdeposito = '' then
		deposito_array = '0';
	else
		deposito_array = pdeposito;
	end if;

	vtpsaldo = (select parauxsld from paramaux where parauxnum = 1 limit 1);
    vdataatual = (select(coalesce((select ptodata from positoq order by ptodata desc limit 1), '0001-01-01')));
    vdataanterior = (select(coalesce((select ptodata from positoq where ptodata <= pdata order by ptodata desc limit 1), '0001-01-01')));
   
    if (pdata < vdataatual) then
	    if (vdataatual <> vdataanterior) then
	    	vdata = vdataanterior;
		else
			vdata = pdata;
	    end if;
	else
		vdata = vdataatual;
	end if;
  

	execute 'select coalesce(
			case
				when ''' || vtpsaldo || '''' || ' = ''O'' and ''' || pdata || '''' || ' = current_date then
(sum(po.psisldatu))
				else (sum(po.psisaldo))
			end,0)
		from possali1 po
		where po.psidata = ''' || vdata || '''' || ' and
		po.produto = ''' || pproduto || '''' || ' and
		(''' || pdeposito ||''' = '''' OR po.deposito = any(ARRAY[' || deposito_array || ']) )' into vsaldo;

	if vtpsaldo = 'O' and pdata = current_date then
		return vsaldo;
	end if;

	 execute 'select coalesce(sum(
			case
			    when t.pritransac = any (array[1, 2, 3, 4, 5, 6, 9, 18]) then t.priquanti
			    when t.pritransac = any (array[11, 12, 13, 14, 15, 16, 19]) then - t.priquanti
			    else 0::numeric
			end),0)
		from toqmovi t
	 where t.priproduto = ''' || pproduto || '''' ||
	 'and (t.pridata > ''' || vdata || '''' || ' and T.PRIDATA <= ''' || pdata || '''' || ')
	 and (''' || pdeposito || ''' = '''' OR t.prideposit = any(ARRAY[' || deposito_array || ']) ) 
	 and (t.itecontrol <> ' || pcontrole || ' or (t.itecontrol = ' || pcontrole || ' and t.prisequen <>
' || psequencia || '))
	 and (t.pritransac in (3, 4, 6, 8, 14, 13, 16, 17, 18) or (select fn_valedoc(t.itecontrol,
t.pritransac, t.operacao, false)) = true)' into qtdmov;

	vsaldo = vsaldo + qtdmov;

	return vsaldo;				
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_saldo_produto_situacao_geral_estoques(date, character, character, numeric, numeric) SET search_path=public, pg_temp;

ALTER FUNCTION fn_saldo_produto_situacao_geral_estoques(date, character, character, numeric, numeric)
  OWNER TO postgres;
