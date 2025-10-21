-- Function: fn_saldo_fiscal(date, character, numeric, numeric, numeric)

-- DROP FUNCTION fn_saldo_fiscal(date, character, numeric, numeric, numeric);

CREATE OR REPLACE FUNCTION fn_saldo_fiscal(pdata date, pproduto character, pdeposito numeric, pcontrole numeric, psequencia numeric)
  RETURNS numeric AS
$BODY$
DECLARE
	vtpsaldo char(1);
	vdata date;
	vsaldo numeric(15,4);
	qtdmov numeric(15,4);

BEGIN
	vtpsaldo = (select parauxsld from paramaux where parauxnum = 1 limit 1);
   vdata    = (select(coalesce((select ptodata from positoq order by ptodata desc limit 1), '0001-01-01')));

	execute 'select coalesce(
			case
				when ''' || vtpsaldo || '''' || ' = ''O'' and ''' || pdata || '''' || ' = current_date then
(sum(po.psisldatu))
				else (sum(po.psisaldo))
			end,0)
		from possali1 po
		where po.psidata = ''' || vdata || '''' || ' and
		po.produto = ''' || pproduto || '''' || ' and
		(po.deposito = ' || pdeposito || ' OR ' || pdeposito || ' = 0)' into vsaldo;

	if vtpsaldo = 'O' and pdata = current_date then
		return vsaldo;
	end if;

	 execute 'select coalesce(sum(
			case
                when (t.pritransac = any (array[1, 2, 3, 4, 5, 6, 9, 18])) and (select fn_valedoc(t.itecontrol,
				t.pritransac, t.operacao, false) = true) then t.priquanti
			    when (t.pritransac = any (array[11, 12, 13, 14, 15, 16])) and (select fn_valedoc(t.itecontrol,
				t.pritransac, t.operacao, false) = true) and ((Select count(0) from CFOPTRAN o where o.CFOPDESTIN = t.operacao)>0) then - t.priquanti
				when (t.pritransac = any (array[12,19])) and (select fn_valedoc(t.itecontrol,
				t.pritransac, t.operacao, false) = false) and ((Select count(0) from CFOPTRAN o where o.CFOPDESTIN = t.operacao)>0) then - t.priquanti
			    when (t.pritransac = any (array[1, 9])) and (select fn_valedoc(t.itecontrol,
				t.pritransac, t.operacao, false) = false) and ((Select count(0) from CFOPTRAN o where o.CFOPORIGEM = t.operacao)>0) then  t.priquanti
				else 0::numeric
			end),0)
		from toqmovi t
	 where t.priproduto = ''' || pproduto || '''' ||
	 'and (t.pridata > ''' || vdata || '''' || ' and T.PRIDATA <= ''' || pdata || '''' || ')
	 and (t.prideposit = ' || pdeposito ||' or ' || pdeposito || ' = 0)
	 and (t.itecontrol <> ' || pcontrole || ' or (t.itecontrol = ' || pcontrole || ' and t.prisequen <>
' || psequencia || ')) and (Select count(0) from DOCTOS Where CONTROLE = t.itecontrol and NOTOBSFISC like ''NF ANULADA%'' )= 0
	 ' into qtdmov;

	vsaldo = vsaldo + qtdmov;
	return vsaldo;				
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_saldo_fiscal(date, character, numeric, numeric, numeric) SET search_path=public, pg_temp;

ALTER FUNCTION fn_saldo_fiscal(date, character, numeric, numeric, numeric)
  OWNER TO postgres;
