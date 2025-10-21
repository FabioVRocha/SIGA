-- Function: pw_fn_calculo_giro_estoque(date, date, text)

-- DROP FUNCTION pw_fn_calculo_giro_estoque(date, date, text);

CREATE OR REPLACE FUNCTION pw_fn_calculo_giro_estoque(pdataini date, pdatafim date, pproduto text)
  RETURNS numeric AS
$BODY$
declare
	Cusven    record;
	Ord1      record;
	Ord2      record;
	Cuspro    record;
	vcontrole int8;
	vpedido   int4;
	vordem    int4;
	vproduto  character(16);
	vquanti	  numeric(15,4);
	vdataof   date;
	vdepo     integer;
	estoqueinicial numeric(15,4);
	estoquefinal   numeric(15,4);
	estoquemedio   numeric(15,4);
	custoprodutosvendidos  numeric(15,4);
	calculogiroestoque    numeric(15,4);
    custoreposicao numeric(15,4); 
	vPeriodo integer;    
begin	
    estoqueinicial = fn_saldo_produto(pdataini, pproduto, 0,0,0);
    --raise notice 'estoque inicial %', estoqueinicial;
   	estoquefinal   = fn_saldo_produto(pdatafim, pproduto, 0,0,0);
    --raise notice 'estoque final %', estoquefinal;
    estoquemedio   = (estoqueinicial + estoquefinal) / 2;
    --raise notice 'estoque medio %', estoquemedio;
    custoprodutosvendidos = 0;
   	calculogiroestoque = 0;
    vPeriodo = (pdatafim::DATE - pdataini::DATE);
    for CusVen in 
    	Select t.itecontrol as vcontrole, doc.notdata as vdata, coalesce(emp.dadmulemp,'N') as vMulEmp, t.priproduto as vproduto, 
		t.prideposit as vdepo, t.priquanti as vquanti--, Count(ord.ordem) as vQordem
    	from toqmovi t
    	inner join doctos doc on doc.controle = t.itecontrol
    	left join dadosemp emp on emp.dadempresa = doc.notclifor
    	left join opera opi ON opi.operacao = t.operacao    	
    	--left join ordem ord on ord.ordproduto = t.priproduto and ord.orddtaber >= pdataini and ord.orddtaber <= pdatafim   	
    	where doc.notdata >= pdataini and doc.notdata <= pdatafim and t.priproduto  = pproduto and
    	t.prisequen < 500 AND doc.notdocto IS NOT NULL AND doc.notdocto <> ''::bpchar 
    	AND doc.notdtdigit IS NOT NULL AND doc.notdtdigit <> '0001-01-01'::date 
    	AND substr(doc.notobsfisc::text, 1, 10) <> 'NF ANULADA'::text AND opi.opeapv = 'S'::bpchar 
    	AND opi.opevlcom = 'S'::bpchar
    	--group by 1,2,3,4,5
    	order by 1    	
    Loop			
		for Cuspro in
			select hicuvlrcu, hicudatal 
			from hiscusto h
			where h.hicuproco = pproduto			
			and h.hicudepo = CusVen.vdepo
			and h.hicudatal = 
			(select Max(hicudatal) from hiscusto h1 where  h1.hicuproco = pproduto
								and h1.hicudatal <= cusven.vdata and h1.hicuvlrcu <> 0 and  h1.hicudepo = CusVen.vdepo
								union
			 select Min(hicudatal) from hiscusto h2 where  h2.hicuproco = pproduto
								and h2.hicudatal > cusven.vdata and h2.hicuvlrcu <> 0 and h2.hicudepo = CusVen.vdepo limit 1 ) limit 1
		loop
			--raise notice 'custo1 %, quanti % data % ', Cuspro.hicuvlrcu, CusVen.vquanti, Cuspro.hicudatal ;	
			if coalesce(Cuspro.hicuvlrcu,0) <> 0 then
				custoprodutosvendidos = custoprodutosvendidos + (Cuspro.hicuvlrcu * CusVen.vquanti);	
			  else
			  	custoreposicao = fn_cusrep(pproduto, CusVen.vdepo, Cusven.vMulEmp);	
	    		custoprodutosvendidos = custoprodutosvendidos  +  (custoreposicao * CusVen.vquanti); 			
			end if;				
		end loop;
	
	end loop;
	--raise notice 'custoprodutosvendidos %, estoquemedio %', custoprodutosvendidos,estoquemedio ;
	if coalesce(custoprodutosvendidos,0) <> 0 AND COALESCE(estoquemedio,0) <> 0 then
		calculogiroestoque = (custoprodutosvendidos / estoquemedio);
	end if;
	--raise notice '**calculogiroestoque %', calculogiroestoque;
	return COALESCE(calculogiroestoque,0);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_calculo_giro_estoque(date, date, text) SET search_path=public, pg_temp;

ALTER FUNCTION pw_fn_calculo_giro_estoque(date, date, text)
  OWNER TO postgres;
