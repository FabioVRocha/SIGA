-- Function: fn_gestio001(json, character)

-- DROP FUNCTION fn_gestio001(json, character);

CREATE OR REPLACE FUNCTION fn_gestio001(p_json json, p_usuario character)
  RETURNS void AS
$BODY$
DECLARE
  cjsontxt json;
  cjsonItens json;
  parcelas json;
  cjsonParcelas json;
  fornecedor json;
  numeroDoPedido numeric;
  numeroDaOrdem numeric;
  codigoFornecedor numeric;
  codigoDaFilial numeric;
  codigoDaCondicaoDePagamento numeric;
  itens json;
  sequenciaItem numeric;
  idProduto numeric;
  codigoInterno text;
  quantidade numeric(15,4);
  simboloDaUnidadeDeMedida text;
  valorUnitario numeric(15,4);
  valorTotal numeric(15,4);
  valorDescontos numeric(15,4);
  valorDescontosPercentual numeric(6,2);
  valorIPI Numeric(15,2);
  valorICMS Numeric(15,2);
  valorICMSST Numeric(15,2);
  valorPIS Numeric(15,2);
  valorCOFINS Numeric(15,2);
  valorFrete Numeric(15,2);
  valorSeguro Numeric(15,2);
  valorOutros Numeric(15,2);
  observacao character(30);
  parcelaId numeric;
  dataDeVencimento date;
  percentual Numeric(15,2);
  valor numeric(15,2);
  v_pronome text;
  v_rqcdtemi date;
  v_pcmgerpco character;
  v_rqcplanej numeric;
  v_rqcprevi date;
  v_rqcpedve numeric;
  v_rqctipvin character(1);
  v_rqcdepos numeric(2);
  v_rqcassis numeric;
  v_umcotvalor numeric(15,4);
  v_cnumeroDaOrdem text;
  cdataDeVencimento text;
  v_temProduto character;
  totalGeral numeric(15,4);
  --OS 4320025
  v_rqccod numeric;
  v_cnumeroDoPedido text;
  --
begin
	
	select pcmgerpco into v_pcmgerpco from cmpparam c where c.pcmpparam = 1;
	delete from umcota u where u.umcotest = p_usuario;
	delete from umcompra u where u.umcomusuar = p_usuario;
	
	for cjsontxt in (select * from json_array_elements(p_json::json -> 'data') ) loop --Faz um laco para ler todas as posicoes
	   numeroDoPedido = cjsontxt ->> 'numeroDoPedido';
	   numeroDaOrdem  = cjsontxt ->> 'numeroDaOrdem';
	   fornecedor     = cjsontxt ->> 'fornecedor';
	   codigoDaFilial = cjsontxt ->> 'codigoDaFilial';
	   codigoDaCondicaoDePagamento = cjsontxt ->> 'codigoDaCondicaoDePagamento';
  
	   if (select count(*) from reqcomp r where r.rqcidgesti = numeroDaOrdem limit 1) > 0 then --Valida se a ordem de compra da plataforma existe no ERP --OS 4320025, alterado "rqccod" por "rqcidgesti"
		   select
				MAX(case when key = 'codigo' then value end) as codigoFornecedor
				into
				codigoFornecedor
			from json_each_text (fornecedor);
		
			if (select count(*) from empresa e where e.empresa = codigoFornecedor limit 1) > 0 then --Valida se o fornecedor da plataforma existe no ERP
				v_temProduto = 'N';
			    for cjsonItens in (select * from json_array_elements(cjsontxt::json -> 'itens') ) loop --Faz um laco para ler todas as posicoes dentro de itens
				    sequenciaItem = cjsonItens ->> 'seq';
				   	idProduto = cjsonItens ->> 'idProduto';
				    codigoInterno = cjsonItens ->> 'codigoInterno';
				    quantidade = cjsonItens ->> 'quantidade';
				    simboloDaUnidadeDeMedida = cjsonItens ->> 'simboloDaUnidadeDeMedida';
				    valorUnitario = cjsonItens ->> 'valorUnitario';
				    valorTotal = cjsonItens ->> 'valorTotal';
				    valorDescontos = cjsonItens ->> 'valorDescontos';
				    valorDescontosPercentual = cjsonItens ->> 'valorDescontosPercentual';
				    valorIPI = cjsonItens ->> 'valorIPI';
				    valorICMS = cjsonItens ->> 'valorICMS';
				    valorICMSST = cjsonItens ->> 'valorICMSST';
				    valorPIS = cjsonItens ->> 'valorPIS';
				    valorCOFINS = cjsonItens ->> 'valorCOFINS';
				    valorFrete = cjsonItens ->> 'valorFrete';
				    valorSeguro = cjsonItens ->> 'valorSeguro';
				    valorOutros = cjsonItens ->> 'valorOutros';
				    observacao = cjsonItens ->> 'observacao';
				    totalGeral = cjsonItens ->> 'totalGeral';
				  
				   select 
				   		pronome into v_pronome
				   from produto p where p.produto = codigoInterno;
				   if (v_pronome <> '' and v_pronome is not null) then
					   select 
					   		rqcdtemi, 
					   		rqcplanej,
					   		rqcprevi,
					   		rqcpedve,
					   		rqctipvin,
					   		rqcdepos,
					   		rqcassis,
					   		r.rqccod 
					   		into 
					   		v_rqcdtemi,
					   		v_rqcplanej,
					   		v_rqcprevi,
					   		v_rqcpedve,
					   		v_rqctipvin,
					   		v_rqcdepos,
					   		v_rqcassis,
					   		v_rqccod
					   from reqcomp r where r.rqcidgesti = numeroDaOrdem and r.produto = codigoInterno limit 1; --OS 4320025, alterado "rqccod" por "rqcidgesti" e add "and r.produto = codigoInterno" 
					  
					   v_umcotvalor = 0;
					   if (v_pcmgerpco) = 'C' then
					   		v_umcotvalor = quantidade;
					   end if;
					   
					   
					   /*if (select 1 from umcota u where u.umcotest = p_usuario and u.umcotfor = codigoFornecedor and u.umcotprod = codigoInterno and u.umcotacao = v_rqccod) > 0 then --OS 4320025, alterado "numeroDaOrdem" por "v_rqccod"
					   		update umcota set 
					   			umcotqtde = umcotqtde   + quantidade,
					   			umcotqtd1  = umcotqtd1  + valorUnitario,
				   				umcotqtd2  = umcotqtd2  + valorTotal,
				   				umcotvlrre = umcotvlrre + valorDescontos,
				   				umcotvlrpr = umcotvlrpr + totalGeral,
				   				umcotbast  = umcotbast  + valorFrete
					   		where u.umcotest = p_usuario and u.umcotfor = codigoFornecedor and u.umcotprod = codigoInterno and u.umcotacao = v_rqccod; --OS 4320025, alterado "numeroDaOrdem" por "v_rqccod"
					   		v_temProduto = 'S';
					   		if (v_pcmgerpco) = 'C' then
					   			update umcota set 
					   				umcotvalor = umcotvalor + quantidade
					   			where u.umcotest = p_usuario and u.umcotfor = codigoFornecedor and u.umcotprod = codigoInterno and u.umcotacao = v_rqccod; --OS 4320025, alterado "numeroDaOrdem" por "v_rqccod"
					   		end if;
					   else
					   		v_temProduto = 'S';*/
					   		insert into umcota (umcotest, umcotfor, umcotprod, umcotprono, umcotqtde, umcotdt, umcotmarca, umcotacao, umcotped, umcotplano, umcotdtpre, umcotreq, umcotxls, umcotdepo, umcottipo,
					   							umcoass, umcotvalor, umcotqtd1, umcotqtd2, umcotvlrre, umcotvlrpr, umcotbast, umcofonc)
					               values (p_usuario, codigoFornecedor, codigoInterno, v_pronome, quantidade, v_rqcdtemi, '', v_rqccod, numeroDoPedido, v_rqcplanej, v_rqcprevi, v_rqcpedve, v_rqctipvin,
		  					               v_rqcdepos, 'O', v_rqcassis, v_umcotvalor, valorUnitario, valorTotal, valorDescontos, totalGeral, valorFrete, observacao);
		  					              --OS 4320025, alterado "numeroDaOrdem" por "v_rqccod"
			           --end if;
		          end if;
		           
			    end loop;
			   
			  	--if (v_temProduto = 'S') then --Caso o pedido de compra lido tenha produtos validos
				    for cjsonParcelas in (select * from json_array_elements(cjsontxt::json -> 'parcelas') ) loop --Faz um laco para ler todas as posicoes dentro de parcelas
				    	parcelaId = cjsonParcelas ->> 'parcelaId';
				    	cdataDeVencimento = cjsonParcelas ->> 'dataDeVencimento';
				    	dataDeVencimento = cdataDeVencimento::date;
					    percentual = cjsonParcelas ->> 'percentual';
					    valor = cjsonParcelas ->> 'valor';
					   
					    --v_cnumeroDaOrdem = numeroDaOrdem::integer::text; --E necessario converter primeiro para "integer", pois a ordem de compra vem no formato "00.00". Assim, ela fica "00" apenas. --OS 4320025, comentado
					    v_cnumeroDoPedido = numeroDoPedido::integer::text; --OS 4320025
					   	if (select 1 from umcompra u where u.umcomusuar = p_usuario and u.umcomdocto = v_cnumeroDoPedido) > 0 then --OS 4320025, alterado "v_cnumeroDaOrdem" para "v_cnumeroDoPedido"
					   	else
					   		insert into umcompra (umcomusuar, umcomdocto, umcomempre, umcomprodu, umcomdata, umcomsld1, umcomsld2, umccontrol) --OS 4320025, removido "umccontrol"
					   			values (p_usuario, v_cnumeroDoPedido, parcelaId, 'NOT', dataDeVencimento, percentual, valor, numeroDoPedido); --OS 4320025, alterado "v_cnumeroDaOrdem" para "v_cnumeroDoPedido" e removido "numeroDoPedido" 
				   		end if;
				    end loop;
			   --end if;
		   end if;
	    end if;
	    
   end loop;
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_gestio001(json, character) SET search_path=public, pg_temp;

ALTER FUNCTION fn_gestio001(json, character)
  OWNER TO postgres;
