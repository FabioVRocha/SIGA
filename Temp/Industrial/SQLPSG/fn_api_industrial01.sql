-- Function: fn_api_industrial01(character, character varying, character)

-- DROP FUNCTION fn_api_industrial01(character, character varying, character);

CREATE OR REPLACE FUNCTION fn_api_industrial01(p_deonde character, p_txtretorno character varying, p_usuario character)
  RETURNS void AS
$BODY$
	declare 
		cjsontxt json;
  		cjsontxt2 json;  		
  		nn numeric(3);  		
  		jsonTam numeric(5);
  		cUsuarioJson char(10);
  		IDToken character(255);
  		nIDIntegracao integer;
  		pedido json;
		cliente json;
		frete json;
		produtos json;
  		cStatusPedidoERP char(1);
  		recLeitura record;
  		recCabecalho record;
  		recPedido record;
  		recCliente record;
  		recProcessoIntegracao record;
  		recProdutos json;
  	    recFrete record;
  		clinhagravacao text;
  		clinhagravacao1 text;
  		dataArquivoRemessa text;
  		nomeRepresentante text;
  		codigoRepresentante text;
  		cnpjCpf text; 
  	    razaoSocial text;
  	   	nomeFantasia text;
  	    codigoERP text;
  	   	endereco text;
  	    bairro text;
  	    email text;
  	   	diaMesAnivContato text;
  	   	statusEmpresa text;
  	    emailBoletos text;
  	    cnpjCpfN text;
  	    nomeCidade text;
  	    siglaEstado text;
  	    telefone text;
  	    fax text;
  	    tipoPessoa text;
  	    --cnpjCpf character(18);
  	   	inscricaoEstadual text;
  	    cpf text;
  	    identidade text;
  	    cobrancaCEP text;
  	   	cEP text;
  	    cobrancaCidade text;
  	    cobrancaSiglaEstado text; 
  	    tipoEmpresa text;
  	    tipoFrete text;
  	    cNPJTransportadora text;
  	    codigoIBGECidade text;
  	    codigoIBGECidadeCobranca text;
  	    origemCliente text;
  	    cobrancaEndereco text;
  	    cobrancaBairro text;
  	    CobrancaTelefone text;
  	    PessoaContato text;
  	    dataCadastro text;
  	    celular text;
  	    telefoneContato text;
  	    faxContato text;
  	    dataAlteracaoCadastro text;
  	    contribuinte text;
  	    complemento text;
  	    tipoPedidoVenda text;
  	    cFOP text;
  	    tabelaPrecoVenda text;
  	    cobrancaBanco text;
  	    modalidadeCobranca text;
  	    condicaoPagamento text;
  	    consumidorFinal text;
  	    numeroPedidoVendaRepresentante text;
  	    codigoTabelaPrecos text;
  	    codigoCondicaoPagamento text;
  	    dataEmissaoPedido text;
  	    dataPrevisaoEntregaPedido text;
  	    percentualDesconto1 text;
  	    percentualDesconto2 text;
  	    percentualDesconto3 text;
  	    percentualDesconto4 text;
  	    percentualDesconto5 text;
  	    tipoPagamento text;
  	    tipoPedido text;
  	    --observacao2 character(180);
  	    cnpjCpfP text;
  	    ordemCompra text;
  	    --tipoFrete character(1);
  	    --cnpjTransportadora character(14);
  	    depositoPedido text;
  	    valor text;
  	    valorDesconto text;
  	    enderecoEntrega text;
  	    cidadeEntrega text;
  	    descricaoCidadeEntrega text;
  	    uf_entrega text;
  	    cep_entrega text;
  	    bairroEntrega text;
  	    ibgeCidadeEntrega text;
  	    origemPedido text;
  	    --ordemCompra character(15);
  	    pedidovendacompleto text;
  	    observacao1 text;
  	    observacao2 text;
  	    observacao1ImpressaNF text;
  	    observacao2ImpressaNF text;
  	    --numeroPedidoVendaRepresentante character(8);
  	    sequencia text;
  	    produtoCodigoERP text;
  	    precoVendaUnitario text;
  	    quantidade text;
  	    acabamento1 text;
  	    acabamento2 text;
  	    acabamento3 text;
  	    acabamento4 text;
  	    acabamento5 text;
  	    desconto1 text;
  	    desconto2 text;
  	    desconto3 text;
  	    desconto4 text;
  	    desconto5 text;
  	    dataPrevisaoItem text;
  	   	promocoesDeVendas text;
  	    percentualComissaoPromocao text;  	   
  	    TabelaPrecoItem text;
  	    precoVendaUnitarioCompleto text;
  	    observacaoProducaoPedido text; -- avaliar varchar
  	    observacaoProducao text; -- avaliar varchar
  	    percentualdorepresentante text;  	  
  	    c1 text;
  	    c2 text;
  	    c3 text;
  		vSeq integer;
	begin
		nn = 1;
   		cjsontxt = p_txtRetorno; 
   		acabamento1 =  '      ';
  		acabamento2 =  '      ';
  		acabamento3 =  '      ';
  		acabamento4 =  '      ';
  		acabamento5 =  '      ';
  		promocoesDeVendas = '   ';
  	    percentualComissaoPromocao = '     ';
  	   	pedidovendacompleto = '           ';
   		promocoesDeVendas = '   ';
  	    percentualComissaoPromocao = '     ';
  	    percentualdorepresentante = '     ';
   		--Busca as Informacoes do JSON
   		--jsonTam = json_array_length(cjsontxt::json -> 'Retorno'); --Busca Quantas posicoes tem o JSON
   		if p_Deonde = 'L' then 
   		
   			delete from umpedpre where UMPEDUSU=p_Usuario;   		
   			
			--For recLeitura in
   			for cjsontxt2 in (select * from json_array_elements(cjsontxt::json -> 'Retorno') ) loop						
					nIDIntegracao = (cjsontxt2 ->>  'IDIntegracao')::int;
					cStatusPedidoERP  = (cjsontxt2 ->>  'StatusPedidoERP')::text;   				
    		
	    		--raise notice 'p1 % p2 %',nIDIntegracao, cStatusPedidoERP;
	    		if nIDIntegracao > 0 then 
    				insert into umpedpre  (UMPEDUSU, UMPEDPED, UMPEDTIPO ) values (p_Usuario, nIDIntegracao, cStatusPedidoERP);
    			end if;
    		end loop;    	
		
		end if;
	
	    
		if p_Deonde = 'I' then 		
		   -- raise notice 'Inclui %', p_Deonde ;
			clinhagravacao = '';
			vSeq = 1;
			delete from txtintba where TXTIBUSU = p_Usuario; -- Limpa Temporário 			
			
			select 
				MAX(case when key = 'APIToken' then value end) as id,
    			MAX(case when key = 'DataArquivoRemessa' then value end) as dataArquivoRemessa,
    			MAX(case when key = 'Pedido' then value end) as pedido
				--MAX(case when key = 'Cliente' then value end) as cliente,
				--MAX(case when key = 'Frete' then value end) as frete,
				--MAX(case when key = 'Produtos' then value end) as produtos
				into
				IDToken,
				dataArquivoRemessa,
				pedido
				--cliente,
				--frete,
				--produtos					
			from json_each_text 
    		(cjsontxt) as json_data;
	
    		--raise notice 'Incluindo % em %', IDToken, dataArquivoRemessa ;
    		
				
			dataArquivoRemessa = Trim(TO_CHAR(TO_DATE(dataArquivoRemessa, 'YYYY-MM-DD'), 'DDMMYYYY'));		
		
			--raise notice 'Incluindo %', dataArquivoRemessa ;
		
			for recPedido in (select key as ckey, value as cvalue from json_each_text(pedido::json) ) loop
				
				If trim(recPedido.ckey) = 'Cliente' then
					cliente = Trim(recPedido.cValue);
					--raise notice 'Cliente %', cliente;
				end if;			
				If trim(recPedido.ckey) = 'Frete' then
					frete = Trim(recPedido.cValue);
					--raise notice 'Frete %', frete;
				end if;				
			
				If trim(recPedido.ckey) = 'CodigoRepresentante' then
       				codigoRepresentante  = trim(recPedido.cvalue);
       			    codigoRepresentante = RPAD(codigoRepresentante, 4, ' '); 
       			   	--raise notice 'codigoRepresentante %',codigoRepresentante;
    			End If;
    			If trim(recPedido.ckey) = 'NomeRepresentante' then
       				nomeRepresentante  = trim(recPedido.cvalue);
       				nomeRepresentante = RPAD(nomeRepresentante, 20, ' '); 
       				--raise notice 'nomeRepresentante %',nomeRepresentante;
    			End If;   
    			If trim(recPedido.ckey) = 'NumeroPedidoVendaRepresentante' then
       				numeroPedidoVendaRepresentante  = trim(recPedido.cvalue);
       				numeroPedidoVendaRepresentante = RPAD(numeroPedidoVendaRepresentante, 8, ' ');
       				--raise notice 'numeroPedidoVendaRepresentante %',numeroPedidoVendaRepresentante;
    			End If;
    			If trim(recPedido.ckey) = 'CodigoTabelaPrecos' then
       				codigoTabelaPrecos  = trim(recPedido.cvalue);
       				codigoTabelaPrecos = RPAD(codigoTabelaPrecos, 3, ' '); 
       				--raise notice 'codigoTabelaPrecos %',codigoTabelaPrecos;
    			End If;
    			If trim(recPedido.ckey) = 'CodigoCondicaoPagamento' then
       				codigoCondicaoPagamento  = trim(recPedido.cvalue);
       				codigoCondicaoPagamento = RPAD(codigoCondicaoPagamento, 2, ' '); 
       				--raise notice 'codigoCondicaoPagamento %',codigoCondicaoPagamento;
    			End If;
    			If trim(recPedido.ckey) = 'DataEmissaoPedido' then
       				dataEmissaoPedido  = TO_CHAR(TO_DATE(recPedido.cvalue,'YYYY-MM-DD'),'DDMMYYYY');
       				dataEmissaoPedido = RPAD(dataEmissaoPedido, 8, ' '); 
       				--raise notice 'dataEmissaoPedido %',dataEmissaoPedido;
    			End If;
    			If trim(recPedido.ckey) = 'DataPrevisaoEntregaPedido' then
       				dataPrevisaoEntregaPedido  = TO_CHAR(TO_DATE(recPedido.cvalue,'YYYY-MM-DD'),'DDMMYYYY');
       				dataPrevisaoEntregaPedido = RPAD(dataPrevisaoEntregaPedido, 8, ' ');
       				--raise notice 'dataPrevisaoEntregaPedido %',dataPrevisaoEntregaPedido;
    			End If;
    			If trim(recPedido.ckey) = 'PercentualDesconto1' then
       				percentualDesconto1  = trim(recPedido.cvalue);
       				percentualDesconto1 = RPAD(percentualDesconto1, 5, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'PercentualDesconto2' then
       				percentualDesconto2  = trim(recPedido.cvalue);
       				percentualDesconto2 = RPAD(percentualDesconto2, 5, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'PercentualDesconto3' then
       				percentualDesconto3  = trim(recPedido.cvalue);
       				percentualDesconto3 = RPAD(percentualDesconto3, 5, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'PercentualDesconto4' then
       				percentualDesconto4  = trim(recPedido.cvalue);
       				percentualDesconto4 = RPAD(percentualDesconto4, 5, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'PercentualDesconto5' then
       				percentualDesconto5  = trim(recPedido.cvalue);
       				percentualDesconto5 = RPAD(percentualDesconto5, 5, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'TipoPagamento' then
       				tipoPagamento  = trim(recPedido.cvalue);
       				tipoPagamento = RPAD(tipoPagamento, 2, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'TipoPedido' then
       				tipoPedido  = trim(recPedido.cvalue);
       				tipoPedido = RPAD(tipoPedido, 3, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'Observacao2' then
       				observacao2  = trim(recPedido.cvalue);
       				observacao2 = RPAD(observacao2, 180, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'OrdemCompra' then
       				ordemCompra  = trim(recPedido.cvalue);
       				ordemCompra = RPAD(ordemCompra, 8, ' ');
    			End If;   			
    			If trim(recPedido.ckey) = 'DepositoPedido' then
       				depositoPedido  = trim(recPedido.cvalue);
       				depositoPedido = RPAD(depositoPedido, 2, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'ValorDesconto' then
       				valorDesconto  = trim(recPedido.cvalue);
       				valorDesconto = RPAD(valorDesconto, 15, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'OrigemPedido' then
       				origemPedido  = trim(recPedido.cvalue);
       				origemPedido = RPAD(origemPedido, 20, ' ');
    			End If;	
    			If trim(recPedido.ckey) = 'OrdemCompra' then
       				OrdemCompra  = trim(recPedido.cvalue);
       				OrdemCompra = RPAD(OrdemCompra, 15, ' ');
    			End If; 
    			If trim(recPedido.ckey) = 'Observacao1' then
       				observacao1  = trim(recPedido.cvalue);
       				observacao1 = RPAD(observacao1, 180, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'Observacao2' then
       				observacao2  = trim(recPedido.cvalue);
       				observacao2 = RPAD(observacao2, 180, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'Observacao1ImpressaNF' then
       				observacao1ImpressaNF  = trim(recPedido.cvalue);
       				observacao1ImpressaNF = RPAD(observacao1ImpressaNF, 1, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'Observacao2ImpressaNF' then
       				observacao2ImpressaNF  = trim(recPedido.cvalue);
       				observacao1ImpressaNF = RPAD(observacao1ImpressaNF, 1, ' ');
    			End If;
    			If trim(recPedido.ckey) = 'ObservacaoProducaoPedido' then
       				observacaoProducaoPedido  = trim(recPedido.cvalue);
       				observacaoProducaoPedido = RPAD(observacaoProducaoPedido, 600, ' ');
    			End If;   		
    		
			end loop;		
			
		
			for recCliente in (select key as ckey, value as cvalue from json_each_text(cliente::json) ) loop
							
				If trim(recCliente.ckey) = 'CnpjCpf' then
       				cnpjCpf  = trim(recCliente.cvalue);       				
    			End If;
				If trim(recCliente.ckey) = 'RazaoSocial' then       				
					razaoSocial  = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'NomeFantasia' then       				
       				nomeFantasia  = trim(recCliente.cvalue);       				
    			End If;
    			If trim(recCliente.ckey) = 'CodigoERP' then
       				codigoERP  = trim(recCliente.cvalue);
    			End If;
				If trim(recCliente.ckey) = 'Endereco' then
       				endereco  = trim(recCliente.cvalue);
    			End If;
				If trim(recCliente.ckey) = 'Bairro' then
       				bairro  = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'Email' then
       				email  = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'DiaMesAnivContato' then
       				diaMesAnivContato  = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'StatusEmpresa' then
       				statusEmpresa  = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'EmailBoletos' then
       				emailBoletos  = trim(recCliente.cvalue);
    			End If; 
  				
		  		If trim(recCliente.ckey) = 'NomeCidade' then
       				nomeCidade = trim(recCliente.cvalue);
    			End If;
		  		If trim(recCliente.ckey) = 'SiglaEstado' then
       				siglaEstado = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'Telefone' then
       				telefone = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'Fax' then
       				fax = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'TipoPessoa' then
       				tipoPessoa = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'Telefone' then
       				telefone = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'InscricaoEstadual' then
       				inscricaoEstadual = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'Identidade' then
       				identidade = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'CobrancaCEP' then
       				cobrancaCEP = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'CEP' then
       				cEP = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'CobrancaCidade' then
       				cobrancaCidade = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'CobrancaSiglaEstado' then
       				cobrancaSiglaEstado = trim(recCliente.cvalue);
    			End If;    			
    			If trim(recCliente.ckey) = 'TipoEmpresa' then
       				tipoEmpresa = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'CodigoIBGECidade' then
       				codigoIBGECidade = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'CodigoIBGECidadeCobranca' then
       				codigoIBGECidadeCobranca = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'OrigemCliente' then
       				OrigemCliente = trim(recCliente.cvalue);
    			End If;
    		    --
    		    If trim(recCliente.ckey) = 'CobrancaEndereco' then
       				cobrancaEndereco = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'CobrancaBairro' then
       				cobrancaBairro = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'CobrancaTelefone' then
       				cobrancaTelefone = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'PessoaContato' then
       				pessoaContato = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'DataCadastro' then
       				DataCadastro = trim(recCliente.cvalue);
    			End If;
    			If trim(recCliente.ckey) = 'Celular' then
       				celular = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'TelefoneContato' then
       				telefoneContato = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'FaxContato' then
       				faxContato = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'DataAlteracaoCadastro' then
       				dataAlteracaoCadastro = trim(recCliente.cvalue); 
       				
    			End If;
    			If trim(recCliente.ckey) = 'Contribuinte' then
       				contribuinte = trim(recCliente.cvalue);       			
    			End If;    			
    			If trim(recCliente.ckey) = 'Complemento' then
       				Complemento = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'TipoPedidoVenda' then
       				TipoPedidoVenda = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'CFOP' then
       				cFOP = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'TabelaPrecoVenda' then
       				tabelaPrecoVenda = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'CobrancaBanco' then
       				cobrancaBanco = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'ModalidadeCobranca' then
       				modalidadeCobranca = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'CondicaoPagamento' then
       				condicaoPagamento = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'ConsumidorFinal' then
       				consumidorFinal = trim(recCliente.cvalue);       			
    			End If;
    			If trim(recCliente.ckey) = 'TipoFrete' then
       				tipoFrete  = trim(recCliente.cvalue);
    			End If;
    			--   		
				
    		
			end loop;
		
			for recFrete in (select key as ckey, value as cvalue from json_each_text(frete::json) ) loop
		
				If trim(recFrete.ckey) = 'CnpjTransportadora' then
       				cNPJTransportadora  = trim(recFrete.cvalue);
       				cNPJTransportadora = RPAD(cNPJTransportadora, 18, ' ');
    			End If;
				If trim(recFrete.ckey) = 'Valor' then
       				valor  = trim(recFrete.cvalue);
       				valor = RPAD(valor, 15, ' ');
    			End If;
    			If trim(recFrete.ckey) = 'EnderecoEntrega' then
       				enderecoEntrega  = trim(recFrete.cvalue);
       				enderecoEntrega = RPAD(enderecoEntrega, 60, ' ');
    			End If;    			
				If trim(recFrete.ckey) = 'DescricaoCidadeEntrega' then
       				descricaoCidadeEntrega  = trim(recFrete.cvalue);
       				descricaoCidadeEntrega = RPAD(descricaoCidadeEntrega, 30, ' ');
    			End If;
    			--If trim(recFrete.ckey) = 'CidadeEntrega' then
       			--	cidadeEntrega  = trim(recFrete.cvalue);
       			--	cidadeEntrega = RPAD(cidadeEntrega, 4, ' ');
    			--End If;
    			If trim(recFrete.ckey) = 'UF_Entrega' then
       				uF_Entrega  = trim(recFrete.cvalue);
       				uF_Entrega = RPAD(uF_Entrega, 2, ' ');
    			End If;
    			If trim(recFrete.ckey) = 'CEP_Entrega' then
       				cEP_Entrega  = trim(recFrete.cvalue);
       				cEP_Entrega = RPAD(cEP_Entrega, 9, ' ');
    			End if;
    			If trim(recFrete.ckey) = 'BairroEntrega' then
       				bairroEntrega  = trim(recFrete.cvalue);
       				bairroEntrega = RPAD(bairroEntrega, 20, ' ');
    			End if;
				If trim(recFrete.ckey) = 'IBGECidadeEntrega' then
       				iBGECidadeEntrega  = trim(recFrete.cvalue);
       				iBGECidadeEntrega = RPAD(iBGECidadeEntrega, 7, ' ');
    			End if;  		
    		
    		
			End loop;
		
			cnpjCpfN = REGEXP_REPLACE(cnpjCpf, '[^0-9]', '', 'g');			
			cnpjCpfN = RPAD(cnpjCpfN::text, 14, ' ');
			cnpjCpf = RPAD(cnpjCpf::text, 18, ' ');
			razaoSocial = RPAD(razaoSocial::text, 40, ' ');
  	   		nomeFantasia = RPAD(nomeFantasia::text, 20, ' ');
	  	    codigoERP = RPAD(codigoERP::text, 7, ' ');
  		   	endereco = RPAD(endereco::text, 60, ' ');
  	    	bairro = RPAD(bairro::text, 20, ' ');
	  	    email = RPAD(email::text, 50, ' ');
  		   	diaMesAnivContato = RPAD(diaMesAnivContato::text, 4, ' ');
  	   		statusEmpresa = RPAD(statusEmpresa::text, 1, ' ');
	  	    emailBoletos = RPAD(emailBoletos::text, 120, ' ');	
	  	    nomeCidade = RPAD(nomeCidade::text, 30, ' ');
	  	   	siglaEstado = RPAD(siglaEstado::text, 2, ' ');
	  	    telefone = RPAD(telefone::text, 14, ' ');
	  	    fax = RPAD(fax::text, 14, ' ');
	  	    tipoPessoa = RPAD(tipoPessoa::text, 1, ' ');
	  	    inscricaoEstadual = RPAD(inscricaoEstadual::text, 20, ' ');
	  	    identidade = RPAD(identidade::text, 10, ' ');
	  	    cobrancaCEP = RPAD(cobrancaCEP::text, 9, ' ');
	  	    cEP = RPAD(cEP::text, 9, ' ');
	  	    cobrancaCidade = RPAD(cobrancaCidade::text, 30, ' ');
	  	    cobrancaSiglaEstado = RPAD(cobrancaSiglaEstado::text, 2, ' ');
	  	    tipoEmpresa = RPAD(tipoEmpresa::text, 1, ' ');
	  	    tipoFrete = RPAD(tipoFrete::text, 9, ' ');
	  	    --cNPJTransportadora = RPAD(cNPJTransportadora::text, 18, ' ');
	  	    codigoIBGECidade = RPAD(codigoIBGECidade::text, 7, ' ');
	  	    codigoIBGECidadeCobranca = RPAD(codigoIBGECidadeCobranca::text, 7, ' ');
	  	    origemCliente = RPAD(origemCliente::text, 1, ' ');
	  	    cobrancaEndereco = RPAD(cobrancaEndereco::text, 60, ' ');
	  	    cobrancaBairro = RPAD(cobrancaBairro::text,20, ' ');
	  	    cobrancaTelefone = RPAD(cobrancaTelefone::text, 14, ' ');
	  	    pessoaContato = RPAD(pessoaContato::text, 25, ' ');
	  	    dataCadastro = RPAD(dataCadastro::text, 10, ' ');
	  	    dataCadastro = Trim(TO_CHAR(TO_DATE(dataCadastro, 'YYYY-MM-DD'), 'DDMMYYYY'));
	  	    celular = RPAD(celular::text, 14, ' ');
	  	    telefoneContato = RPAD(telefoneContato::text, 14, ' ');
	  	    faxContato = RPAD(faxContato::text, 14, ' ');
	  	    dataAlteracaoCadastro = RPAD(dataAlteracaoCadastro::text, 10, ' ');
	  	    dataAlteracaoCadastro = Trim(TO_CHAR(TO_DATE(dataAlteracaoCadastro, 'YYYY-MM-DD'), 'DDMMYYYY'));
	  	    contribuinte = RPAD(contribuinte::text, 12, ' ');
	  	    complemento = RPAD(complemento::text, 60, ' ');
	  	    tipoPedidoVenda = RPAD(tipoPedidoVenda::text, 3, ' ');
	  	    cFOP = RPAD(cFOP::text, 10, ' ');
	  	    tabelaPrecoVenda = RPAD(tabelaPrecoVenda::text, 3, ' ');
	  	    cobrancaBanco = RPAD(cobrancaBanco::text, 3, ' ');
	  	    modalidadeCobranca = RPAD(modalidadeCobranca::text, 2, ' ');
	  	    condicaoPagamento = RPAD(condicaoPagamento::text, 2, ' ');
	  	    consumidorFinal = RPAD(consumidorFinal::text, 1, ' ');
	  	    cidadeEntrega = '    ';
	  	   
	  	    -- EE ------------------			
			clinhagravacao = 'EE';		
			clinhagravacao = clinhagravacao || Trim(dataArquivoRemessa::text) || RPAD(nomeRepresentante::TEXT, 20, ' ') || RPAD(codigoRepresentante::TEXT, 4, ' ');  -- 35 car.					
			--raise notice 'EE- %',clinhagravacao ;
			insert into txtintba (txtibusu, txtibseq, txtibli1) values(p_Usuario, vSeq, clinhagravacao );
			vSeq = vSeq + 1;
		
			-- E1 -----------------
			c1='';
		  	c2='';
		  	c3=''; 			
			clinhagravacao1 = 'E1';			
			clinhagravacao = clinhagravacao1 || cnpjCpfN::TEXT ||razaoSocial::text||nomeFantasia::text ||codigoERP::text||endereco::text||bairro::text||email::text||diaMesAnivContato::text||statusEmpresa::text||emailBoletos::text;
			--raise notice 'E1- %',clinhagravacao ;
			c1=substring(clinhagravacao, 1, 200);
	  	   	if length(clinhagravacao) > 200 then
	  	   		c2=substring(clinhagravacao, 201, 400);
	  	   		if length(clinhagravacao) > 400 then
	  	   			c3=substring(clinhagravacao, 401, 600);
	  	   		end if;
	  	   	end if;	
	  	   	
	  	    insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq, c1, c2, c3 );
			vSeq = vSeq + 1;
		
		
			-- E2 -----------------
			c1='';
		  	c2='';
		  	c3=''; 						
			clinhagravacao = 'E2';			
			clinhagravacao=clinhagravacao||cnpjCpfN::text||nomeCIdade::text||siglaEstado::text||telefone::text||fax::text||tipoPessoa::text||cnpjCpf::text||inscricaoEstadual::text||cnpjCpf::text||identidade::text;
			clinhagravacao=clinhagravacao::text||cobrancaCEP::text||cEP::text||cobrancaCidade::text||cobrancaSiglaEstado::text||tipoEmpresa::text||tipoFrete::text; 
			clinhagravacao=clinhagravacao::text|| cNPJTransportadora::text || codigoIBGECidade::text|| codigoIBGECidadeCobranca::text || origemCliente::text;			
			--raise notice 'E2- %',clinhagravacao ;
			c1=substring(clinhagravacao, 1, 200);
	  	   	if length(clinhagravacao) > 200 then
	  	   		c2=substring(clinhagravacao, 201, 400);
	  	   		if length(clinhagravacao) > 400 then
	  	   			c3=substring(clinhagravacao, 401, 600);
	  	   		end if;
	  	   	end if;	  	   	  	   	
			insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq, c1, c2, c3 );
			vSeq = vSeq + 1;
		
		
			-- E3 -----------------
			c1='';
		  	c2='';
		  	c3='';
			
			
			clinhagravacao= 'E3';
			clinhagravacao=clinhagravacao||cnpjCpfN::text||cobrancaEndereco::text||cobrancaBairro::text||cobrancaTelefone::text||pessoaContato::text||dataCadastro::text||celular::text||telefoneContato::text;
			clinhagravacao=clinhagravacao::text||faxContato::text||dataAlteracaoCadastro::text ||contribuinte::text||complemento::text||tipoPedidoVenda::text||cFOP||tabelaPrecoVenda::text||cobrancaBanco::text;
			clinhagravacao=clinhagravacao||modalidadeCobranca||condicaoPagamento||consumidorFinal;
			--raise notice 'E3- %',clinhagravacao ;
			c1=substring(clinhagravacao from  1 for 200);
	  	   	if length(clinhagravacao) > 200 then
	  	   		c2=substring(clinhagravacao from 201 for 200);
	  	   		if length(clinhagravacao) > 400 then
	  	   			c3=substring(clinhagravacao from 401 for 200);
	  	   		end if;
	  	   	end if;	  	   	  	   	
			insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq, c1, c2, c3 );
			vSeq = vSeq + 1;
			
			-- P1 --------------
			c1='';
		  	c2='';
		  	c3=''; 
			
			clinhagravacao = 'P1';			
			clinhagravacao=clinhagravacao||NumeroPedidoVendaRepresentante::text||CodigoERP::text||CodigoTabelaPrecos::text||CodigoCondicaoPagamento::text||DataEmissaoPedido::text||DataPrevisaoEntregaPedido::text;
			clinhagravacao=clinhagravacao||PercentualDesconto1::text||PercentualDesconto2::text||PercentualDesconto3::text||PercentualDesconto4::text||PercentualDesconto5::text||TipoPagamento::text||TipoPedido::text||Observacao2::text;
			clinhagravacao=clinhagravacao||CnpjCpf::text||OrdemCompra::text||promocoesDeVendas::text||percentualComissaoPromocao::text||TipoFrete::text||cNPJTransportadora::text||DepositoPedido::text||Valor::text||ValorDesconto::text;
			clinhagravacao=clinhagravacao||enderecoEntrega::text||cidadeEntrega::text||descricaoCidadeEntrega::text||uF_Entrega::text||cEP_Entrega::text||bairroEntrega::text||iBGECidadeEntrega::text||origemPedido::text||ordemCompra::text||pedidovendacompleto::text; 
			--raise notice 'P1- %',clinhagravacao ;						
			c1=substring(clinhagravacao from 1 for 200);
	  	   	if length(clinhagravacao) > 200 then
	  	   		c2=substring(clinhagravacao from 201 for 200);
	  	   		if length(clinhagravacao) > 400 then
	  	   			c3=substring(clinhagravacao from 401 for 200);
	  	   		end if;
	  	   	end if;	
	  	    
			insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq,  c1, c2, c3 );
			vSeq = vSeq + 1;
		
				
			-- PO --------------
			c1='';
		  	c2='';
		  	c3=''; 
			
			clinhagravacao = 'PO';			
			clinhagravacao=clinhagravacao||observacao1::text||observacao2::text||observacao1ImpressaNF::text ||observacao2ImpressaNF::text;
			--raise notice 'PO- %',clinhagravacao ;
			c1=substring(clinhagravacao from 1 for 200);
	  	   	if length(clinhagravacao) > 200 then
	  	   		c2=substring(clinhagravacao from 201 for 200);
	  	   		if length(clinhagravacao) > 400 then
	  	   			c3=substring(clinhagravacao from 401 for 200);
	  	   		end if;
	  	   	end if;		   	  	   	
			insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq,  c1, c2, c3 );
			vSeq = vSeq + 1;
			clinhagravacao = '';
			
			-- P2 --------			
			for recProdutos in (select * from json_array_elements(cjsontxt::json -> 'Produtos') )	 loop
				 
				--raise notice 'Dados %', recProdutos;	
    				sequencia = recProdutos ->> 'Sequencia' ;
    		    	sequencia = RPAD(sequencia, 3, ' ');

       				produtoCodigoERP = recProdutos ->> 'ProdutoCodigoERP';
       				produtoCodigoERP = RPAD(produtoCodigoERP, 16, ' ');
    			 
				
       				
       				precoVendaUnitario  = recProdutos ->> 'PrecoVendaUnitario';
       				precoVendaUnitario = RPAD(precoVendaUnitario, 10, ' ');
    			
       				quantidade  = recProdutos ->> 'Quantidade';
       				quantidade = RPAD(quantidade, 5, ' ');
    			
       				desconto1  = recProdutos ->> 'Desconto1'::text ;
       				desconto1 = RPAD(desconto1, 5, ' ');       				
    			
       				desconto2  = recProdutos ->> 'Desconto2'::text ;
       				desconto2 = RPAD(desconto2, 5, ' ');
    			
       				desconto3  = recProdutos ->> 'Desconto3'::text ;
       				desconto3 = RPAD(desconto3, 5, ' ');
    			
       				desconto4  = recProdutos ->> 'Desconto4'::text ;
       				desconto4 = RPAD(desconto4, 5, ' ');
    			
       				desconto5  = recProdutos ->> 'Desconto5'::text ;
       				desconto5 = RPAD(desconto5, 5, ' ');
    			
       				cfop  = recProdutos ->> 'Cfop' ;
       				cfop = RPAD(cfop, 10, ' ');
    			
       				dataPrevisaoItem  = recProdutos ->> 'DataPrevisaoItem' :: text;       				
       				dataPrevisaoItem = coalesce(RPAD(dataPrevisaoItem, 10, ' '),'');
       				if 	dataPrevisaoItem <> '' then
       					dataPrevisaoItem = Trim(Substring(dataPrevisaoItem from 9 for 2)||Substring(dataPrevisaoItem from 6 for 2)||Substring(dataPrevisaoItem from 1 for 4));
       					else
       					dataPrevisaoItem = '        ';
       				end if;
    			
       				tabelaPrecoItem  = recProdutos ->> 'TabelaPrecoItem' ;
       				tabelaPrecoItem = RPAD(TabelaPrecoItem, 3, ' ');
    			
       				precoVendaUnitarioCompleto  = recProdutos ->> 'PrecoVendaUnitarioCompleto' ;
       				precoVendaUnitarioCompleto = RPAD(precoVendaUnitarioCompleto, 15, ' ');
    			
       				observacaoProducao  = recProdutos ->> 'ObservacaoProducao' ;       				
       				observacaoProducao = RPAD(observacaoProducao, 600, ' ');		
				    			
    		    
    			--
    			c1='';
		  	    c2='';
		  	    c3=''; 
    			clinhagravacao = 'P2';    			
    			clinhagravacao = clinhagravacao||numeroPedidoVendaRepresentante::text||sequencia||produtoCodigoERP||precoVendaUnitario||quantidade;
    			clinhagravacao = clinhagravacao||acabamento1::text||acabamento2::text||acabamento3::text||acabamento4::text||acabamento5::text||desconto1::text||desconto2::text||desconto3::text;
    			clinhagravacao = clinhagravacao||desconto4::text||desconto5::text||cfop::text||dataPrevisaoItem::text || tabelaPrecoItem::text||precoVendaUnitarioCompleto::text;
    			--raise notice 'P2- %',clinhagravacao ;
    			c1=substring(clinhagravacao from 1 for 200);
	  	   		if length(clinhagravacao) > 200 then
	  	   			c2=substring(clinhagravacao from 201 for 200);
	  	   			if length(clinhagravacao) > 400 then
	  	   				c3=substring(clinhagravacao from 401 for 200);
	  	   			end if;
	  	   		end if;	 	   	  	   	
				insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq,  c1, c2, c3 );
				vSeq = vSeq + 1;  		
    		
			end loop;	
		
			-- PP ---------------			
			c1='';
		  	c2='';
		  	c3=''; 
		    
			clinhagravacao = 'PP';
			clinhagravacao=clinhagravacao||coalesce(observacaoProducaoPedido::text,' ');
			--raise notice 'PP- %',clinhagravacao ;
			c1=substring(clinhagravacao from 1 for 200);
	  	   	if length(clinhagravacao) > 200 then
	  	   		c2=substring(clinhagravacao from 201 for 200);
	  	   		if length(clinhagravacao) > 400 then
	  	   			c3=substring(clinhagravacao from 401 for 200);
	  	   		end if;
	  	   	end if;		   	  	   	
			insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq,  c1, c2, c3 );
			vSeq = vSeq + 1;
		
		
			-- PI ------------------- 
			c1='';
	  	    c2='';
	  	    c3=''; 
			
			clinhagravacao = 'PI';
			clinhagravacao=clinhagravacao||coalesce(observacaoProducao::text, ' ');
			--raise notice 'PI- %',clinhagravacao ;
			c1=substring(clinhagravacao from 1 for 200);
	  	   	if length(clinhagravacao) > 200 then
	  	   		c2=substring(clinhagravacao from 201 for 200);
	  	   		if length(clinhagravacao) > 400 then
	  	   			c3=substring(clinhagravacao from 401 for 200);
	  	   		end if;
	  	   	end if;		   	  	   	
			insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq,  c1, c2, c3 );
			vSeq = vSeq + 1;
		
		
			-- PR --------------------
			c1='';
		  	c2='';
		  	c3=''; 
			
			
			clinhagravacao= 'PR' ;
		    clinhagravacao=clinhagravacao||codigoRepresentante::text||percentualdorepresentante::text ;
			--raise notice 'PR- %',clinhagravacao ;
		   	c1=substring(clinhagravacao from 1 for 200);
	  	   	if length(clinhagravacao) > 200 then
	  	   		c2=substring(clinhagravacao from 201 for 200);
	  	   		if length(clinhagravacao) > 400 then
	  	   			c3=substring(clinhagravacao from 401 for 200);
	  	   		end if;
	  	   	end if;		   	  	   	
			insert into txtintba (txtibusu, txtibseq, txtibli1,  txtibli2,  txtibli3) values(p_Usuario, vSeq,  c1, c2, c3 );
			vSeq = vSeq + 1;
			clinhagravacao = '';  
	  	   
	  	   
				
		
		end if; -- Inclusão de Pedido
		
	END;
$BODY$
  LANGUAGE plpgsql VOLATILE 
  COST 100;
ALTER FUNCTION fn_api_industrial01(character, character varying, character) SET search_path=public, pg_temp;

ALTER FUNCTION fn_api_industrial01(character, character varying, character)
  OWNER TO postgres;
