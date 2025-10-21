-- Function: fn_previsoes_recebimento_pedido_venda(integer, character)

-- DROP FUNCTION fn_previsoes_recebimento_pedido_venda(integer, character);

CREATE OR REPLACE FUNCTION fn_previsoes_recebimento_pedido_venda(IN pedido_param integer, IN condicao_param character)
  RETURNS TABLE(prenumero integer, predata date, prevalor numeric, premodalidade character, dataantecipa date, valorantecipa numeric) AS
$BODY$
DECLARE
    ns INT := 0;
    num INT := 0;
    registro RECORD;
    antecipacao RECORD;
    numeroparcela INT := 0;
    diapedido DATE;
    totalpedido numeric(15,2);
	totalcompra numeric(15,2);
    valorprimeiraparcela numeric(15,2);
    infosped RECORD;
    infositenspedido RECORD;
    quitacao DATE;
    pcmdtbcp CHARACTER(1);
    totalipi numeric(15,2);
    totalvlrst numeric(15,2);
    valorfinalsemalteracao numeric(15,2);
    acum numeric(15,2);
    valorfinalimpo numeric(15,2);
    valorfinal numeric(15,2);
    dataitem DATE;
   	comtotal numeric(15,2);
    pedidoprodutos RECORD;
    cmptotal numeric(15,2);   	
    previsoesretorna RECORD;
    totaprazo numeric(15,2);
    vlaprazo numeric(15,2);
   	parauxemb char(1);
   	pedpemb char(1);
   	vlrtot numeric(15,2);
   	compnum numeric(10);
   	dia numeric(2);
   	dataparcela date;
   	--valorantecipa numeric(15,2);
   	--dataantecipa date;
   	compvalor numeric(15,2);
   	compdata date;
   	vlfrete numeric(15,2);
   	vlrst numeric(15,2);
   	ipiaprazo numeric(15,2);
   	vlripi numeric(15,2);
   	cdata character(50);
   	infosempresa RECORD;
begin
	--drop table if exists pedido_temp;
	--create TEMPORARY table pedido_temp (
	--	pedidovenda numeric(8),
	--	parcela numeric(2),
	--	datadaparcela date,
	--	valorparcela numeric(15,2),
	--	valorantecipacao numeric(15,2),
	--	dataantecipacao date,
	--	premodalidade character(2),
	--	CONSTRAINT pedido_temp_pk PRIMARY KEY (pedidovenda, parcela)
	--);
	--CASO NAO TENHA CONDICAO DE PAGAMENTO
	if (condicao_param is null or condicao_param = '') then
	    FOR registro IN --faz um laco de repeticao para cada registro encontrado na tabela previcom
	        SELECT p.prenumero AS prenumero, p.predata AS predata, p.prevalor AS prevalor, p.premodc as premodc
	        FROM previpg p
	        WHERE p.pedido = pedido_param
	    LOOP
	        ns := ns + 1;
	        prenumero := registro.prenumero;
	        predata := registro.predata;
	        prevalor := registro.prevalor;
	        num := registro.prenumero;
	        premodalidade := registro.premodc;
	        
	        -- Inicializacao dos valores a cada iteracao do loop
	        valorantecipa := 0;
	        dataantecipa := '0001-01-01';
	
	        -- Busca Valor de Antecipacao de acordo com a parcela atual
	        FOR antecipacao IN
	            SELECT l.lactransa, l.lacvltot, l.laclanca
	            FROM lancai l
	            inner join vlrante v on v.vladata = l.laclanca and v.vlaseq = l.lacseq and v.vlaempresa > 0 and v.vlantecipa > 0
		        WHERE l.prepedido = pedido_param AND l.prepedseq = prenumero and ((l.lactransa <> '9' and l.lactransa <> '5' and l.lactransa <> '6') or (l.lactransa = '9' and l.laccontrol > 0) )
		        	and v.vlaempresa > 0 and v.vlantecipa > 0
	        LOOP
	            valorantecipa := valorantecipa + antecipacao.lacvltot;
	            dataantecipa := antecipacao.laclanca; -- Atribuicao de data de antecipacao
	        END LOOP;
			
	        -- Retorna os valores da tabela para cada registro encontrado
	        RETURN NEXT;
	    END LOOP;
    --CASO TENHA CONDICAO DE PAGAMENTO
    else
    	--Alimenta as informacoes da tabela condpag na variavel registro
    	select into registro 
    			c.conddi12, c.conddi11, c.conddi10, c.conddi09, c.conddi08, c.conddi07, c.conddi06, c.conddi05, c.conddi04, c.conddi03, c.conddi02, c.conddi01,
		       c.condpe12, c.condpe11, c.condpe10, c.condpe09, c.condpe08, c.condpe07, c.condpe06, c.condpe05, c.condpe04, c.condpe03, c.condpe02, c.condpe01, c.condipi, c.condst,
		       c.condtipo, c.conddia, c.condmes, c.condfrete
		from condpag c
		where c.condicao = condicao_param;
			
		--Busca a informacao da data de fatura e do valor final do pedido de compra
	    SELECT 
	    	p.pedido,
			p.pedmodcob,
			p.pedprevi,
			p.peddbasev,
			p.pedconsufi,
			p.pedcliente 
		INTO infosped
		FROM pedido p
		WHERE p.pedido = pedido_param;
	
		select 
			e.empcontrib
		into infosempresa
		from empresa e
		where e.empresa = infosped.pedcliente;
		
		--Busca os parametros do pedido
		select coalesce(p.parauxemb,'N') into parauxemb	from paramaux p where p.parauxnum = 1;
		select coalesce(p.pedpemb,'N') into pedpemb from paramped p where p.pedparam = 1;
		--Busca informacoes do valor e IPI do pedido de venda (baseado no objeto P-VLRPED)
		select
			SUM(CASE WHEN ((p4.pemocont = 0 or p4.pemocont is null) or (p4.pemocont <> 0 and parauxemb = 'S' and pedpemb = 'S')) then
					(CASE WHEN o.operec = 'S' then
						p.pprvlipi + p.ppripifrv - (COALESCE(pdesc.pddvlripi,0) + COALESCE(pdesc.pddprcipi,0))
					end)
				END) AS ipiaprazo,
			SUM(
					p.pprvlsoma - (p.ppricmfic + p.pprdesfic) + p.pprvlipi + p.ppripifrv + p.pprvlfrete + p.pprfreval + p.pprdespesa + p.pprvlrsub + p.pprsubfrv + 
					COALESCE(NULLIF(stpis.pstpvlrpis, 0::numeric), NULLIF(stpis.pstpvlr2pi, 0::numeric), 0::numeric) + COALESCE(NULLIF(stpis.pstpvlrcof, 0::numeric),
					NULLIF(stpis.pstpvlr2co, 0::numeric), 0::numeric) - COALESCE(pdesc.vlr_desconto, 0::numeric)
				) AS vlaprazo,
			SUM(CASE WHEN o.operec = 'S' then
					(CASE WHEN (p4.pemocont = 0 or p4.pemocont is null) or (p4.pemocont <> 0 and parauxemb = 'S' and pedpemb = 'S') then
						coalesce(p.pprvlrsub,0) + coalesce(p.pprsubfrv,0)
					END)
				else
					(CASE WHEN (c.cdtcfop <> '' and c.cdtcfop is not null) then
						coalesce(p.pprvlrsub,0) + coalesce(p.pprsubfrv,0) 
					END)
				end) as vlrst,
			SUM(CASE WHEN o.operec = 'S' then
					(CASE WHEN (p4.pemocont = 0 or p4.pemocont is null) or (p4.pemocont <> 0 and parauxemb = 'S' and pedpemb = 'S') then
						coalesce(p.pprvlfrete,0) + coalesce(p.pprfreval,0) - (coalesce(pdesc.pddvlrfret,0) + coalesce(pdesc.pddprcfret,0)) 
					END)
				end) as vlfrete
		into infositenspedido
		FROM pedprodu p
		LEFT JOIN opera o ON o.operacao = p.pproperaca
		LEFT JOIN cfoptit c ON c.cdtcfop = p.pproperaca
		LEFT JOIN pedstpis stpis ON stpis.pstppedido = p.pedido AND stpis.pstpsequen = p.pprseq
		LEFT JOIN ( SELECT pd.pddpedido,
            pd.pddsequen,
            pddvlripi,
            pddprcipi,
            pddvlrfret,
            pddprcfret,
            COALESCE(pd.pddvlrprod, 0::numeric) + COALESCE(pd.pddprcprod, 0::numeric) + COALESCE(pd.pddvlripi, 0::numeric) + COALESCE(pd.pddprcfret, 0::numeric) + COALESCE(pd.pddvldesp, 0::numeric) + COALESCE(pd.pddvlrfret, 0::numeric) + COALESCE(pd.pddprdesp, 0::numeric) + COALESCE(pd.pddprcipi, 0::numeric) AS vlr_desconto
           FROM peddesco pd) pdesc ON pdesc.pddpedido = p.pedido AND pdesc.pddsequen = p.pprseq
		left join proembo p4 on p4.pemocont = p.pedido and p4.pemoemsq = p.pprseq and p4.pemoorig = 'PD'
		where p.pedido = pedido_param;

	
		numeroparcela := 1;
		acum := 0;
		totaprazo := coalesce(infositenspedido.vlaprazo,0);
		vlaprazo := coalesce(infositenspedido.vlaprazo,0) - coalesce(infositenspedido.ipiaprazo,0);
		vlrtot := coalesce(vlaprazo,0) + coalesce(infositenspedido.ipiaprazo,0);
	    if registro.condtipo <> 'V' then
	    	compnum := numeroparcela;
	    	prenumero := compnum;
	    	premodalidade := infosped.pedmodcob;
	    	dia := EXTRACT(day from infosped.pedprevi);
	    	if dia >= registro.conddia then
	    		predata := infosped.pedprevi + INTERVAL '1 month';
	    	else
	    		if (registro.condmes) = 'P' then
	    			predata := infosped.pedprevi + INTERVAL '1 month';
	    		else
	    			predata := infosped.pedprevi;
	    		end if;
	    	end if;
	    	cdata := EXTRACT(year from predata) || '/' || EXTRACT(month from predata) || '/' || registro.conddia; --Atribui a data de vencimento das condicoes de pagamento para o registro.
	    	predata := cdata::date;
	        compvalor := vlrtot;
	       	prevalor := compvalor;
	        -- Busca Valor de Antecipacao de acordo com a parcela atual
    		dataantecipa := '0001-01-01';
			valorantecipa := 0;
	        FOR antecipacao IN
	            SELECT l.lactransa, l.lacvltot, l.laclanca
	            FROM lancai l
	            inner join vlrante v on v.vladata = l.laclanca and v.vlaseq = l.lacseq and v.vlaempresa > 0 and v.vlantecipa > 0
	            WHERE l.prepedido = pedido_param AND l.prepedseq = prenumero and ((l.lactransa <> '9' and l.lactransa <> '5' and l.lactransa <> '6') or (l.lactransa = '9' and l.laccontrol > 0) )
	            	  and v.vlaempresa > 0 and v.vlantecipa > 0
	        LOOP
	            valorantecipa := valorantecipa + antecipacao.lacvltot;
	            dataantecipa := antecipacao.laclanca; -- Atribuicao de data de antecipacao
	        END LOOP;
	        --
	       	acum := vlrtot;
	       	--insert into pedido_temp values (infosped.pedido, numeroparcela, predata, compvalor, valorantecipa, dataantecipa, infosped.pedmodcob);
	    	RETURN NEXT;
	    else
	    	premodalidade := infosped.pedmodcob;
			acum := 0;
			valorfinal := vlrtot;
    		valorfinalsemalteracao := vlrtot;
			--Subtrai as informacoes de IPI e ICMS antes de iniciar o looping
	    	if (registro.condipi) = 'S' then
				valorfinal := valorfinal - coalesce(infositenspedido.ipiaprazo,0);
			end if;
			if (registro.condst) = 'S' then
				valorfinal := valorfinal - coalesce(infositenspedido.vlrst,0);
			end if;
			if (registro.condfrete) = 'S' then
				valorfinal := valorfinal - coalesce(infositenspedido.vlfrete,0);
			end if;
		    valorfinalimpo := valorfinal;
		   	quitacao = infosped.pedprevi;
		    --
		  	for i in 1..12 loop
		    	prenumero := 0;
	    		if (registro.conddi01) > 0 and i = 1 then
	    			prenumero := numeroparcela;
	    			if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := infosped.pedprevi;
    				else
	    				predata := quitacao + registro.conddi01;
	    			end if;
	    			valorfinal := round(valorfinalimpo * (registro.condpe01 / 100),2);
	    			if (registro.condipi) = 'S' then
	    				valorfinal := valorfinal + coalesce(infositenspedido.ipiaprazo,0);
	    			end if;
					if (registro.condst) = 'S' then
	    				valorfinal := valorfinal + coalesce(infositenspedido.vlrst,0);
	    			end if;
	    			if (registro.condfrete) = 'S' then
						valorfinal := valorfinal + coalesce(infositenspedido.vlfrete,0);
					end if;
	    			if (registro.condpe01) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi02) > 0 and i = 2 then
	    			prenumero := numeroparcela;
	    			if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '1 month';
    				else
	    				predata := quitacao + registro.conddi02;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe02 / 100),2);
			       	if (registro.condpe01 + registro.condpe02) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi03) > 0 and i = 3 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '2 month';
    				else
	    				predata := quitacao + registro.conddi03;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe03 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi04) > 0 and i = 4 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '3 month';
    				else
	    				predata := quitacao + registro.conddi04;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe04 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi05) > 0 and i = 5 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '4 month';
    				else
	    				predata := quitacao + registro.conddi05;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe05 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi06) > 0 and i = 6 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '5 month';
    				else
	    				predata := quitacao + registro.conddi06;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe06 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi07) > 0 and i = 7 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '6 month';
    				else
	    				predata := quitacao + registro.conddi07;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe07 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi08) > 0 and i = 8 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '7 month';
    				else
	    				predata := quitacao + registro.conddi08;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe08 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi09) > 0 and i = 9 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '8 month';
    				else
	    				predata := quitacao + registro.conddi09;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe09 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi10) > 0 and i = 10 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '9 month';
    				else
	    				predata := quitacao + registro.conddi10;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe10 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09 + registro.condpe10) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi11) > 0 and i = 11 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '10 month';
    				else
	    				predata := quitacao + registro.conddi11;
	    			end if;
			        valorfinal := round(valorfinalimpo * (registro.condpe11 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09 + registro.condpe10 + registro.condpe11) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        prevalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi12) > 0 and i = 12 then
	    			prenumero := numeroparcela;
			        if (infosped.peddbasev > 0) then --Caso a data base de vencimento esteja em branco, faz o calculo com o valor informado na condicao de pagamento
	    				predata := quitacao + interval '11 month';
    				else
	    				predata := quitacao + registro.conddi12;
	    			end if;
			       	valorfinal := round(valorfinalimpo * (registro.condpe12 / 100),2);
			        valorfinal := valorfinalsemalteracao - acum;
			        prevalor := valorfinal;
	    		end if;
	    		-- Busca Valor de Antecipacao de acordo com a parcela atual
	    		dataantecipa := '0001-01-01';
    			valorantecipa := 0;
		        FOR antecipacao IN
		            SELECT l.lactransa, l.lacvltot, l.laclanca
		            FROM lancai l
		            inner join vlrante v on v.vladata = l.laclanca and v.vlaseq = l.lacseq and v.vlaempresa > 0 and v.vlantecipa > 0
		            WHERE l.prepedido = pedido_param AND l.prepedseq = prenumero and ((l.lactransa <> '9' and l.lactransa <> '5' and l.lactransa <> '6') or (l.lactransa = '9' and l.laccontrol > 0) )
		            	  and v.vlaempresa > 0 and v.vlantecipa > 0
		        LOOP
		            valorantecipa := valorantecipa + antecipacao.lacvltot;
		            dataantecipa := antecipacao.laclanca; -- Atribuicao de data de antecipacao
		        END LOOP;
	    		if (prenumero) <> 0 then
	    			--if (select count(*) from pedido_temp where pedidovenda = infosped.pedido and datadaparcela = predata limit 1) > 0 then
	    			--	update pedido_temp set valorparcela = valorparcela + prevalor, valorantecipacao = valorantecipacao + valorantecipa, dataantecipacao = dataantecipa
	    			--	where pedidovenda = infosped.pedido and datadaparcela = predata;
	    			--else
	--	insert into pedido_temp values (infosped.pedido, prenumero, predata, prevalor, valorantecipa, dataantecipa, infosped.pedmodcob);
	    			--end if;
	    			numeroparcela := numeroparcela + 1;
	    			RETURN NEXT;
		    	end if;
		    end loop;
	   end if;
	   -- Faz um laço das informações acumuladas e retorna da função
	    --numeroparcela := 1;
		--FOR previsoesretorna IN
	    --    SELECT p.parcela, p.datadaparcela, p.valorparcela, p.valorantecipacao, p.dataantecipacao, p.premodalidade
	    --    FROM pedido_temp p order by datadaparcela
	    --loop
	    --    prenumero := numeroparcela;
	    --    predata := previsoesretorna.datadaparcela;
	    --    prevalor := previsoesretorna.valorparcela;
	    --    valorantecipa := previsoesretorna.valorantecipacao;
	    --    dataantecipa := previsoesretorna.dataantecipacao;
	    --   	premodalidade := previsoesretorna.premodalidade;
	    --    numeroparcela := numeroparcela + 1;
	    --    RETURN NEXT;
	    --END LOOP;
	end if;
    RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION fn_previsoes_recebimento_pedido_venda(integer, character) SET search_path=public, pg_temp;

ALTER FUNCTION fn_previsoes_recebimento_pedido_venda(integer, character)
  OWNER TO postgres;
