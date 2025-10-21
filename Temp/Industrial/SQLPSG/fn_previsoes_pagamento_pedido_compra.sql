-- Function: fn_previsoes_pagamento_pedido_compra(integer, character)

-- DROP FUNCTION fn_previsoes_pagamento_pedido_compra(integer, character);

CREATE OR REPLACE FUNCTION fn_previsoes_pagamento_pedido_compra(IN compra_param integer, IN condicao_param character)
  RETURNS TABLE(compnum integer, compdata date, compvalor numeric, valorantecipa numeric, dataantecipa date, compobs text) AS
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
    infositenscompra RECORD;
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
    compraprodutos RECORD;
    cmptotal numeric(15,2);   	
    previsoesretorna RECORD;
begin
	--drop table if exists compra_temp;
	--create TEMPORARY table compra_temp (
	--	pedidocompra numeric(8),
	--	parcela numeric(2),
	--	dataparcela date,
	--	valorparcela numeric(15,2),
	--	valorantecipacao numeric(15,2),
	--	dataantecipacao date,
	--	observacao character(250),
	--	CONSTRAINT compra_temp_pk PRIMARY KEY (pedidocompra, parcela)
	--);
	--CASO NAO TENHA CONDICAO DE PAGAMENTO
	if (condicao_param is null or condicao_param = '') then
	    FOR registro IN --faz um laco de repeticao para cada registro encontrado na tabela previcom
	        SELECT p.COMPNUM AS compnum, p.COMPDATA AS compdata, p.COMPVALOR AS compvalor, p.COMPOBS AS compobs
	        FROM previcom p
	        WHERE p.COMPRA = compra_param AND p.COMPNUM > num
	    LOOP
	        ns := ns + 1;
	        compnum := registro.compnum;
	        compdata := registro.compdata;
	        compvalor := registro.compvalor;
	        compobs := registro.compobs;
	        num := registro.compnum;
	        
	        -- Inicializacao dos valores a cada iteracao do loop
	        valorantecipa := 0;
	        dataantecipa := '0001-01-01';
	
	        -- Busca Valor de Antecipacao de acordo com a parcela atual
	        FOR antecipacao IN
	            SELECT l.lactransa, l.lacvltot, l.laclanca
	            FROM lancai l
	            WHERE l.precompra = compra_param AND l.precomseq = compnum
	        LOOP
	            IF (antecipacao.lactransa = '3' OR antecipacao.lactransa = '4') THEN
	                valorantecipa := valorantecipa + antecipacao.lacvltot;
	            ELSIF (antecipacao.lactransa = '7' OR antecipacao.lactransa = '8') THEN
	                valorantecipa := valorantecipa - antecipacao.lacvltot;
	            END IF;
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
		       c.condpe12, c.condpe11, c.condpe10, c.condpe09, c.condpe08, c.condpe07, c.condpe06, c.condpe05, c.condpe04, c.condpe03, c.condpe02, c.condpe01, c.condipi, c.condst
		from condpag c
		where c.condicao = condicao_param;
		
		select c.pcmdtbcp into pcmdtbcp from cmpparam c where c.pcmpparam = 1; --Busca a informacao do parametro pcmdtbcp
	
		--Busca a informacao da data de fatura e do valor final do pedido de compra
	    SELECT 
	    	c.compra,
		    c.comfatur,
		    c.comvlfinal,
		    c.comvlfrete,
		    c.comperfret,
		    c.comrespons
		INTO infosped
		FROM compra c 
		WHERE c.compra = compra_param;
	
		--Acumula a informacao do valor total do IPI e do ST, alem de buscar a ultima data de previsao do item.
		select
			--Utilizado quando a variavel pcmdtbcp for igual a F
			sum(
			case when CMPBCIPI = 0 then
			    round(CMPTOTPRO + round(CMPTOTPRO * (CMPIPI/100),2) + CMPVLICMST,2) - CMPTOTPRO - CMPVLICMST 
			else
			    round(CMPTOTPRO + round(CMPBCIPI * (CMPIPI/100),2) + CMPVLICMST,2) - CMPTOTPRO - CMPVLICMST 
			end) as totalipi,
			SUM (CMPVLICMST) as totalvlrst,
			--
			--Utilizado quando a variavel pcmdtbcp for diferente de F
			sum(
			case when CMPBCIPI = 0 then
			    round(CMPTOTPRO + round(CMPTOTPRO * (CMPIPI/100),2) + CMPVLICMST,2) 
			else
			    round(CMPTOTPRO + round(CMPBCIPI * (CMPIPI/100),2) + CMPVLICMST,2) 
			end) as comtotal
			--
		into infositenscompra
		from compra3 c 
		where c.compra = compra_param;
		
		numeroparcela := 1;
		acum := 0;
		/*
		if (pcmdtbcp) <> 'F' then --Caso seja Data base para Calculo das Previsoes de Pagamento seja diferente de Data Fatura, deve realizar o processo pelos itens do pedido, caso contrario, sera pelo cabecalho.
			  for compraprodutos in
			  		select
			  			c.compra,
			  			c.cmpprev,
			  			c.cmptotpro as cmptotproduto,
			  			c.cmpvlicmst,
			  			c.cmpbcipi,
			  			c.cmpipi			
			  		from compra3 c
			  		WHERE c.compra = compra_param
			  		order by c.compra, c.cmpseq 
			  loop
				if compraprodutos.cmpbcipi = 0 then
				    cmptotal := round(compraprodutos.cmptotproduto + round(compraprodutos.cmptotproduto * (compraprodutos.cmpipi/100),2) + compraprodutos.cmpvlicmst,2);
				else
				    cmptotal := round(compraprodutos.cmptotproduto + round(compraprodutos.cmpbcipi * (compraprodutos.cmpipi/100),2) + compraprodutos.cmpvlicmst,2);
				end if;
				acum := 0;  
				quitacao := compraprodutos.cmpprev;
				valorfinal := cmptotal;
				if (infosped.comvlfrete <> 0 or infosped.comperfret <> 0) and infosped.comrespons ='F' then
					if (infosped.comperfret <> 0) then
						valorfinalimpo := round((valorfinal * infosped.comperfret) / 100,2);
					else
						if (infositenscompra.comtotal) <> 0 then
							valorfinalimpo := round((valorfinal * infosped.comvlfrete) / infositenscompra.comtotal, 2);
						else
							valorfinalimpo := 0;
						end if;
					end if;
					valorfinal := valorfinal + valorfinalimpo;
				end if;
	    		valorfinalsemalteracao := valorfinal; 
 				--Subtrai as informacoes de IPI e ICMS antes de iniciar o looping
	    		totalipi := cmptotal - compraprodutos.cmptotproduto - compraprodutos.cmpvlicmst;
	    	    totalvlrst := compraprodutos.cmpvlicmst;
		    	if (registro.condipi) = 'S' then
					valorfinal := valorfinal - totalipi;
				end if;
				if (registro.condst) = 'S' then
					valorfinal := valorfinal - totalvlrst;
				end if;
			    valorfinalimpo := valorfinal;
			    --
			  	for i in 1..12 loop
			    	compnum := 0;
		    		if (registro.conddi01) > 0 and i = 1 then
		    			compnum := numeroparcela;
		    			compdata := quitacao + registro.conddi01;
		    			valorfinal := round(valorfinalimpo * (registro.condpe01 / 100),2);
		    			if (registro.condipi) = 'S' then
		    				valorfinal := valorfinal + totalipi;
		    			end if;
						if (registro.condst) = 'S' then
		    				valorfinal := valorfinal + totalvlrst;
		    			end if;
		    			if (registro.condpe01) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi02) > 0 and i = 2 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi02;
				        valorfinal := round(valorfinalimpo * (registro.condpe02 / 100),2);
				       	if (registro.condpe01 + registro.condpe02) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi03) > 0 and i = 3 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi03;
				        valorfinal := round(valorfinalimpo * (registro.condpe03 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi04) > 0 and i = 4 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi04;
				        valorfinal := round(valorfinalimpo * (registro.condpe04 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi05) > 0 and i = 5 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi05;
				        valorfinal := round(valorfinalimpo * (registro.condpe05 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi06) > 0 and i = 6 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi06;
				        valorfinal := round(valorfinalimpo * (registro.condpe06 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi07) > 0 and i = 7 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi07;
				        valorfinal := round(valorfinalimpo * (registro.condpe07 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi08) > 0 and i = 8 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi08;
				        valorfinal := round(valorfinalimpo * (registro.condpe08 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi09) > 0 and i = 9 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi09;
				        valorfinal := round(valorfinalimpo * (registro.condpe09 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi10) > 0 and i = 10 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi10;
				        valorfinal := round(valorfinalimpo * (registro.condpe10 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09 + registro.condpe10) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi11) > 0 and i = 11 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi11;
				        valorfinal := round(valorfinalimpo * (registro.condpe11 / 100),2);
				       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09 + registro.condpe10 + registro.condpe11) = 100 then
		    				valorfinal := valorfinalsemalteracao - acum;
		    			end if;
				        compvalor := valorfinal;
				        acum := acum + valorfinal;
		    		end if;
		    		if (registro.conddi12) > 0 and i = 12 then
		    			compnum := numeroparcela;
				        compdata := quitacao + registro.conddi12;
				       	valorfinal := round(valorfinalimpo * (registro.condpe12 / 100),2);
				        valorfinal := valorfinalsemalteracao - acum;
				        compvalor := valorfinal;
		    		end if;
		    		-- Busca Valor de Antecipacao de acordo com a parcela atual
		    		dataantecipa := '0001-01-01';
	    			valorantecipa := 0;
			        FOR antecipacao IN
			            SELECT l.lactransa, l.lacvltot, l.laclanca
			            FROM lancai l
			            WHERE l.precompra = compra_param AND l.precomseq = compnum
			        LOOP
			            valorantecipa := valorantecipa + antecipacao.lacvltot;
			            dataantecipa := antecipacao.laclanca; -- Atribuicao de data de antecipacao
			        END LOOP;
		    		if (compnum) <> 0 then
		    			--if (select count(*) from compra_temp where pedidocompra = compraprodutos.compra and dataparcela = compdata limit 1) > 0 then
		    			--	update compra_temp set valorparcela = valorparcela + compvalor, valorantecipacao = valorantecipacao + valorantecipa, dataantecipacao = dataantecipa
		    			--	where pedidocompra = compraprodutos.compra and dataparcela = compdata;
		    			--else
		    			--	insert into compra_temp values (compraprodutos.compra, compnum, compdata, compvalor, valorantecipa, dataantecipa, '');
		    			--end if;
		    			numeroparcela := numeroparcela + 1;
		    			RETURN NEXT;
			    	end if;
			    end loop;
			  end loop;
		else
		*/
	    	--Caso for por Data Futura considera essa, caso contrario, considera a do ultimo item do pedido de compra
	    	quitacao := infosped.comfatur;
	    	valorfinal = infosped.comvlfinal;
	    	valorfinalsemalteracao = infosped.comvlfinal; 
	    	--Subtrai as informacoes de IPI e ICMS antes de iniciar o looping
	    	if (registro.condipi) = 'S' then
				valorfinal := valorfinal - infositenscompra.totalipi;
			end if;
			if (registro.condst) = 'S' then
				valorfinal := valorfinal - infositenscompra.totalvlrst;
			end if;
		    valorfinalimpo := valorfinal;
			--
	    	for i in 1..12 loop
		    	compnum := 0;
	    		if (registro.conddi01) > 0 and i = 1 then
	    			compnum := numeroparcela;
	    			compdata := quitacao + registro.conddi01;
	    			valorfinal := round(valorfinalimpo * (registro.condpe01 / 100),2);
	    			if (registro.condipi) = 'S' then
	    				valorfinal := valorfinal + infositenscompra.totalipi;
	    			end if;
					if (registro.condst) = 'S' then
	    				valorfinal := valorfinal + infositenscompra.totalvlrst;
	    			end if;
	    			if (registro.condpe01) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi02) > 0 and i = 2 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi02;
			        valorfinal := round(valorfinalimpo * (registro.condpe02 / 100),2);
			       	if (registro.condpe01 + registro.condpe02) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi03) > 0 and i = 3 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi03;
			        valorfinal := round(valorfinalimpo * (registro.condpe03 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi04) > 0 and i = 4 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi04;
			        valorfinal := round(valorfinalimpo * (registro.condpe04 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi05) > 0 and i = 5 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi05;
			        valorfinal := round(valorfinalimpo * (registro.condpe05 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi06) > 0 and i = 6 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi06;
			        valorfinal := round(valorfinalimpo * (registro.condpe06 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi07) > 0 and i = 7 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi07;
			        valorfinal := round(valorfinalimpo * (registro.condpe07 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi08) > 0 and i = 8 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi08;
			        valorfinal := round(valorfinalimpo * (registro.condpe08 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi09) > 0 and i = 9 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi09;
			        valorfinal := round(valorfinalimpo * (registro.condpe09 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi10) > 0 and i = 10 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi10;
			        valorfinal := round(valorfinalimpo * (registro.condpe10 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09 + registro.condpe10) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi11) > 0 and i = 11 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi11;
			        valorfinal := round(valorfinalimpo * (registro.condpe11 / 100),2);
			       	if (registro.condpe01 + registro.condpe02 + registro.condpe03 + registro.condpe04 + registro.condpe05 + registro.condpe06 + registro.condpe07 + registro.condpe08 + registro.condpe09 + registro.condpe10 + registro.condpe11) = 100 then
	    				valorfinal := valorfinalsemalteracao - acum;
	    			end if;
			        compvalor := valorfinal;
			        acum := acum + valorfinal;
	    		end if;
	    		if (registro.conddi12) > 0 and i = 12 then
	    			compnum := numeroparcela;
			        compdata := quitacao + registro.conddi12;
			       	valorfinal := round(valorfinalimpo * (registro.condpe12 / 100),2);
			        valorfinal := valorfinalsemalteracao - acum;
			        compvalor := valorfinal;
	    		end if;
	    		-- Busca Valor de Antecipacao de acordo com a parcela atual
	    		dataantecipa := '0001-01-01';
	    		valorantecipa := 0;
		        FOR antecipacao IN
		            SELECT l.lactransa, l.lacvltot, l.laclanca
		            FROM lancai l
		            WHERE l.precompra = compra_param AND l.precomseq = compnum
		        LOOP
		            valorantecipa := valorantecipa + antecipacao.lacvltot;
		            dataantecipa := antecipacao.laclanca; -- Atribuicao de data de antecipacao
		        END LOOP;
	    		numeroparcela := numeroparcela + 1;
	    		if (compnum) <> 0 then
	    			--if (select count(*) from compra_temp where pedidocompra = infosped.compra and dataparcela = compdata limit 1) > 0 then
	    			--	update compra_temp set valorparcela = valorparcela + compvalor, valorantecipacao = valorantecipacao + valorantecipa
	    			--	where pedidocompra = infosped.compra and dataparcela = compdata;
	    			--else
	    			--	insert into compra_temp values (infosped.compra, compnum, compdata, compvalor, valorantecipa, dataantecipa, '');
	    			--end if;
		    		RETURN NEXT;
		    	end if;
		    end loop;
	   --end if;
	   -- Faz um laço das informações acumuladas e retorna da função
	    --numeroparcela := 1;
		--FOR previsoesretorna IN
	    --    SELECT p.parcela, p.dataparcela, p.valorparcela, p.valorantecipacao, p.dataantecipacao, p.observacao
	    --    FROM compra_temp p order by dataparcela
	    --loop
	    --    compnum := numeroparcela;
	    --    compdata := previsoesretorna.dataparcela;
	    --    compvalor := previsoesretorna.valorparcela;
	    --    valorantecipa := previsoesretorna.valorantecipacao;
	    --    dataantecipa := previsoesretorna.dataantecipacao;
	    --    numeroparcela := numeroparcela + 1;
	    --    RETURN NEXT;
	    --END LOOP;
	end if;
	--drop table if exists compra_temp;
    RETURN;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION fn_previsoes_pagamento_pedido_compra(integer, character)
  OWNER TO postgres;
