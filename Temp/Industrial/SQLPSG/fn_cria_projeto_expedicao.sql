-- Function: fn_cria_projeto_expedicao()

-- DROP FUNCTION fn_cria_projeto_expedicao();

CREATE OR REPLACE FUNCTION fn_cria_projeto_expedicao()
  RETURNS trigger AS
$BODY$
DECLARE
	r_prjexsa RECORD;
	r_doctos RECORD;
	r_ntvped1 RECORD;
	v_prjaxcont numeric;
	v_prjaxproj numeric;
	v_prjaxped numeric;
	v_prjaxseq numeric;
	v_prjaxprd text;
	v_prjaxdprod text;
	v_prjaxqtde numeric;
	v_prjaxqtsep numeric;
	v_prjaxcvol numeric;
	v_prjaxdvol text;
	v_prjaxpsvol numeric;
	v_prjaxqtvol numeric;
	v_prjaxrast text;
    v_parexpcod numeric;
   	v_dataatual date;
   	v_horaatual text;
    v_usuario text;
    v_ip varchar;
    v_log text;
    v_nomeprojeto text;
    v_clientePedido numeric;
    v_nomeCliente text;
    v_engfanest char(1);
   	v_parexsvolp char(1);
	v_parexsusal char(1);
	v_parexsvcus char(1);
	v_prjesparc char(1);
	v_prjesorcs numeric;
 	v_priorilote numeric;
 	v_parexssnf char(1);
 	v_umpetpro text;
	v_umpetqtd numeric;
	v_umpetseq numeric;
	v_controle numeric;
	v_seqnot numeric;
	v_saldo numeric;
	v_pprquanti numeric;
	v_temnf numeric;
	v_prodpriem numeric;
	v_prjessqte numeric;
	v_prjesspre text;
	v_prjessqts numeric;
	v_prjesspri numeric;
	v_xpai text;
	v_procusrep numeric;
	v_multiempresa char(1);
	v_deposito numeric;
	v_procusrepaux numeric;
	v_parexssoma char(1);
	v_existe numeric;
	v_prjesspritab numeric;
	v_saldoaux numeric;
	v_lgaversao text;
	v_pfanta char(1);
	v_parexssep char(1);
	v_prjessepa numeric;
    v_prjesstip char(1);
    v_prjesspro text;
    v_prjessppai text;
    v_prjessseq numeric;
    v_prjessqtd numeric;
   	v_prjessqts_aux numeric;
   	v_qtdeaux numeric;
   	v_negativo char(1);
	v_tipocri char(1);
	v_pridata date;
	v_parexstra char(1);
	v_conftrans char(1);
	v_qtdetra numeric;
	v_prjv1ordn numeric;
	v_qtdsep numeric;
	v_qtdejavol numeric;
	v_prjessorc numeric;
	v_rastreado char(1);
	v_qtderast numeric;
	v_prjessrasc numeric;
	v_prjessrase numeric;
	v_quanti numeric;
	v_ltrasaldo numeric;
	v_notpcontro numeric;
	v_exprojeto text;
	v_parexsdet numeric;
	v_prjesscon numeric;
	v_prjv1seqv numeric;
	v_count numeric;
	v_continua char(1);
	v_saldoRestante numeric;
	v_prjv2etiq numeric;
	v_prjv2seqe numeric;
	v_cprjv2etiq text;
	v_existeEtiqueta char(1);
	v_prorastre char(1);
	v_parexrast char(1);
    v_prjesesem numeric; --OS 4298425
    v_prjeseorc numeric; --OS 4298425
begin
	--Usuario do processo
	v_usuario = fn_get_session_var('industrial.usuario');
	--Se o usuario nao estiver definido na sessao, pega o final do IP.
	if v_usuario is null then
		v_ip = (select inet_client_addr()::varchar);
		v_usuario = substring(v_ip, length(v_ip)- 9);
	end if;
	v_lgaversao = substring((select d.dadversao from dadosemp d order by d.dadversao desc limit 1),1,9);
	v_multiempresa = coalesce((select d.dadmulemp from dadosemp d where d.dadempresa = 1),'N');

	select 
 		coalesce(p.parexsvolp,'N'),
 		coalesce(p.parexsusal,'N'),
 		coalesce(p.parexsvcus,'N'),
 		coalesce(p.parexssnf,'N'),
 		coalesce(p.parexssoma,'N'),
 		coalesce(p.parexssep, 'N'),
 		coalesce(p.parexstra, 'N'),
 		p.parexsdet,
 		coalesce(p.parexrast, 'N')
 		into
 		v_parexsvolp,
 		v_parexsusal,
 		v_parexsvcus,
 		v_parexssnf,
		v_parexssoma,
		v_parexssep,
		v_parexstra,
		v_parexsdet,
		v_parexrast
 	from paramexp p where p.parexpara = 1;
 
 	select 
 		coalesce(p.paraungrq,'N'),
 		coalesce(p.paraucrrq,'N' )
 		into
 		v_negativo,
 		v_tipocri
 	from paramaux p where p.parauxnum = 1;

	--Codigo baseado no objeto P-EXPSI98 como principal. A partir desse foi visto os objetos pra dentro que realizam os processos.
	--prjaxmov = 1 esta liberado para importacao
 	if (new.prjaxmov = 1) then
	--for r_prjexsa in (select * from prjexsa p where p.prjaxmov = 1 order by prjaxmov, prjaxped, prjaxseq, prjaxprd, prjaxproj) loop --Para cada registro da tabela "prjexsa" vai ser realizado o processo
		--if v_prjaxped is not null and v_prjaxped <> 0 and ((r_prjexsa.prjaxped <> v_prjaxped) or (r_prjexsa.prjaxped = v_prjaxped and r_prjexsa.prjaxseq <> v_prjaxseq)) then
		  
		--end if;
	
		v_prjaxcont  = new.prjaxcont;  --Codigo do contador do movimento
		v_prjaxproj  = new.prjaxproj;  --Numero identificador do projeto
		v_prjaxped   = new.prjaxped;   --Codigo do pedido
		v_prjaxseq   = new.prjaxseq;   --Codigo da sequencia do pedido
		v_prjaxprd   = new.prjaxprd;   --Codigo do produto do pedido (sera esse o separado)
		v_prjaxdprod = new.prjaxdprod; --Descricao do produto
		v_prjaxqtde  = new.prjaxqtde;  --Quantidade do item no pedido
		v_prjaxqtsep = new.prjaxqtsep; --Quantidade separada
		v_prjaxcvol  = new.prjaxcvol;  --Codigo do volume
		v_prjaxdvol  = new.prjaxdvol;  --Descricao do volume
		v_prjaxpsvol = new.prjaxpsvol; --Peso do volume
		v_prjaxqtvol = new.prjaxqtvol; --Quantidade do produto no volume
		v_prjaxrast  = trim(new.prjaxrast);  --Codigo do lote de rastreabilidade
		v_dataatual  = current_date;         --Data atual
		v_horaatual  = current_time::char(8);   --Hora atual
		
		v_prorastre = coalesce((select p2.prorastre from produto p2 where p2.produto = v_prjaxprd),'N');
		--Verifica se o pedido na sequencia e produto definidos existem e se o codigo do lote de rastreabilidade no produto do pedido existe.
		if (coalesce((select 1 from pedprodu p where p.pedido = v_prjaxped and p.pprseq = v_prjaxseq and trim(p.pprproduto) = trim(v_prjaxprd) limit 1),0) = 1
		     and ((v_prorastre = 'N') or (v_parexrast = 'N') or (coalesce((select 1 from lotrast l where l.ltracodig = trim(Trim(v_prjaxrast)) and l.ltraprodu = trim(v_prjaxprd) limit 1),0) = 1 and v_prorastre = 'S' and v_parexrast = 'S')) and v_prjaxqtsep >= v_prjaxqtvol) then
		     	--raise notice '1 Pedido %, Produto % ', v_prjaxped, v_prjaxprd;
		     	if coalesce((select 1 from prjexsi1 p where p.prjessepa = v_prjaxped limit 1),0) <> 1 then
		     		--O pedido nao tem projeto, entao devemos fazer a criacao do cabecalho
		     		--Busca o proximo codigo disponivel para o projeto (objeto P-PRJ001)
		     		v_parexpcod = coalesce((select parexpcod from paramexp p2 where p2.parexpara = 1 limit 1),0);
		     		if (v_parexpcod < 1) then
		     			v_parexpcod = 1;
		     		end if;
					v_parexpcod = v_parexpcod + 1;
					update paramexp set parexpcod = v_parexpcod + 1 where parexpara = 1;
					
					v_clientePedido = (select pedcliente from pedido p where p.pedido = v_prjaxped limit 1);
					v_nomeCliente = (select empnome from empresa e where e.empresa = v_clientePedido limit 1);
					v_nomeprojeto = v_prjaxped || ' - ' || v_nomeCliente; --Concatena o codigo do pedido e o nome da empresa do pedido para ser o nome do projeto
				
					--Cria o cabecalho (objeto P-EXPSI04)
					--raise notice '2 Pedido %, %, % ', v_usuario, v_dataatual, v_horaatual;
					insert into prjexsim (prjescodi, prjesdesc, prjesstat, prjesorcs, prjesorce, prjesplaca, prjesmotor, prjesparc, prjesidtmv, prjesihrmv, prjesiusmv) values
										 (v_parexpcod, v_nomeprojeto, 'E', 0, 0, '', '', 'N', v_dataatual, v_horaatual, v_usuario);
										
					insert into prjexsi1 (prjescodi, prjessepa, prjesstip, prjessseq, prjesspre, prjessppai, prjessqem, prjessorc, prjesscon, prjesspri, prjesstop) values
										 (v_parexpcod, 0, 'P', 0, ' ', '', 0, 999999, 2, 0, 1);
										 
					insert into prjexsi2 (prjescodi, prjesempa, prjesetip, prjeseseq, prjesepre, prjeseppai, prjesepla, prjeseorc, prjesecon, prjesepri, prjesetop, prjeseqpv, prjesesem) values
										 (v_parexpcod, 0, 'P', 0, ' ', ' ', ' ', 999999, 2, 0, 1, 0, 0);
										 
					--raise notice 'Aqui 0';
					v_horaatual = current_time::char(8);
					v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
		      		v_horaatual = v_horaatual || ' ' || v_count;
					v_log = 'Integracao MasterLink/Smart WMS. Incluido Projeto ' || v_parexpcod;
					insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
										('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
				else
					--Caso o pedido tenha projeto, busca o codigo do projeto
					--raise notice '3 Pedido % ', v_prjaxped;
					v_parexpcod = (select p.prjescodi from prjexsi1 p where p.prjessepa = v_prjaxped limit 1);
		     	end if;
		     	--raise notice 'Aqui 0.1';
		     	
		     	--Objeto P-EXPSI05
		     	select 
		     		coalesce(e.engfanest,'N')
		     		into
		     		v_engfanest
		     	from engparam e where e.engparcod = 1;
		        
	     		select 
	     			coalesce(p.prjesparc,'N'), 
	     			coalesce(p.prjesorcs,0)
	     			into 
	     			v_prjesparc,
	     			v_prjesorcs 
	     		from prjexsim p where p.prjescodi = v_parexpcod limit 1;
	     	
		     	if (v_parexsvolp <> 'S') then --Caso nao controle volumes/agrupamento por produto pai, entao nao tera projeto parcial, nao precisaria nem buscar esse campo, mas por precaucao estamos fazendo.
		     		v_prjesparc = 'N';
		     	end if;
		     
		     	v_priorilote = coalesce((select p.lcaseque from pedido p where p.pedido = v_prjaxped and (p.lcapecod is not null and p.lcapecod <> '')),0);
		     
		     	--Informacoes do pedido ja previamente cadastradas na tabela "prjexsia", entao nao precisamos buscar no pedido.
		     	v_umpetpro = v_prjaxprd;
	     		v_umpetqtd = v_prjaxqtde;
	     		v_umpetseq = v_prjaxseq;
		     	--select p.pprproduto, p.pprquanti,	p.pprseq into v_umpetpro, v_umpetqtd, v_umpetseq from pedprodu p where p.pedido = v_prjaxped and p.pprseq = v_prjaxseq;
		     
		     	select 
		     		p.deposito 
		     		into 
		     		v_deposito
		     	from pedido p where p.pedido = v_prjaxped;
		     	--raise notice 'Aqui 1';
		     
		     	if (v_parexssnf = 'S') then
		     		--Busca o saldo do item do pedido conforme objeto P-SLDPEDPR
		     		--filtra ja validando o documento
		     		for r_doctos in (select * from doctos d where d.notpedido = v_prjaxped and (d.notdtdigit <> '0001-01-01' and d.notdtdigit is not null) and (d.notdocto <> '0001-01-01' and d.notdocto is not null)) loop
		     			v_controle = r_doctos.controle;
		     			v_seqnot   = v_umpetseq;
		     			v_umpetqtd = v_umpetqtd - coalesce((select sum(t.priquanti) from toqmovi t
		     									  inner join opera o on t.operacao = o.operacao where t.itecontrol = v_controle and t.prisequen = v_seqnot and t.priproduto = v_umpetpro and
		     									  (o.opeped = 'S' and o.opeentgfut <> 'S') or (o.opeentgfut = 'S' and o.operemefut = 'R')),0);
		     		end loop;
		     	
		     		for r_ntvped1 in (select * from ntvped1 n where n.ntvpedi = v_prjaxped and n.ntvseped = v_umpetseq) loop 
		     			v_controle = r_ntvped1.ntvnota;
		     			v_seqnot   = r_ntvped1.ntvsenot;
		     			--valida o documento
		     			if coalesce((select 1 from doctos d where d.controle = v_controle and (d.notdtdigit <> '0001-01-01' and d.notdtdigit is not null) and (d.notdocto <> '0001-01-01' and d.notdocto is not null)),0) > 0 then
		     				v_umpetqtd = v_umpetqtd - coalesce((select sum(t.priquanti) from toqmovi t
		     									  inner join opera o on t.operacao = o.operacao where t.itecontrol = v_controle and t.prisequen = v_seqnot and t.priproduto = v_umpetpro and
		     									  (o.opeped = 'S' and o.opeentgfut <> 'S') or (o.opeentgfut = 'S' and o.operemefut = 'R')),0);
		     			end if;
		     		end loop;
		     		
		     		if (v_umpetqtd < 0) then
		     			v_umpetqtd = 0;
		     		end if;
		     		v_saldo = v_umpetqtd;
		     	end if;
		     	--raise notice 'Aqui 2';
		     	--Caso o projeto seja parcial
		     	if (v_prjesparc = 'S') then
		     		v_saldo = v_umpetqtd;
		     		if (v_parexsusal <> 'S') then --Parametro "Utilizar apenas saldo nao faturado do pedido para projeto de expedicao"
		     			v_umpetqtd = v_umpetqtd;
		     		else
		     			v_pprquanti = v_umpetqtd;
		     			--Busca saldo dos itens dos pedidos na expedicao conforme objeto "P-SLDPEDEXP"
		     			for r_doctos in (select * from doctos d where d.notpedido = v_prjaxped) loop
		     				v_controle = r_doctos.controle;
		     				v_seqnot   = v_umpetseq;
		     				v_temnf    = coalesce((select 1 from prjexsi5 p where p.prjesmcon = v_controle and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_umpetseq limit 1),0);
		     				if (v_temnf <> 1) then
		     					v_temnf = coalesce((select 1 from prjexsi4 p where p.prjesencon = v_controle and p.prjesempa = v_prjaxped and p.prjesetip = 'P' and p.prjeseseq = v_umpetseq limit 1),0);
		     					if (v_temnf <> 1) then
				     				v_pprquanti = v_pprquanti - coalesce((select sum(t.priquanti) from toqmovi t 
				     											inner join opera o on t.operacao = o.operacao
				     											where t.itecontrol = v_controle and t.prisequen = v_seqnot and t.priproduto = v_umpetpro and 
				     											(o.opeped = 'S' and o.opeentgfut <> 'S') or (o.opeentgfut = 'S' and o.operemefut = 'R')),0);
								end if;
							end if;
		     			end loop;
		     		
		     			for r_ntvped1 in (select * from ntvped1 n where n.ntvpedi = v_prjaxped and n.ntvseped = v_umpetseq) loop
		     				v_controle = r_ntvped1.ntvnota;
		     				v_seqnot   = r_ntvped1.ntvsenot;
		     				v_temnf    = coalesce((select 1 from prjexsi5 p where p.prjesmcon = v_controle and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_umpetseq limit 1),0);
		     				if (v_temnf <> 1) then
		     					v_temnf = coalesce((select 1 from prjexsi4 p where p.prjesencon = v_controle and p.prjesempa = v_prjaxped and p.prjesetip = 'P' and p.prjeseseq = v_umpetseq limit 1),0);
		     					if (v_temnf <> 1) then
		     						v_pprquanti = v_pprquanti - coalesce((select sum(t.priquanti) from toqmovi t 
				     											inner join opera o on t.operacao = o.operacao
				     											where t.itecontrol = v_controle and t.prisequen = v_seqnot and t.priproduto = v_umpetpro and 
				     											(o.opeped = 'S' and o.opeentgfut <> 'S') or (o.opeentgfut = 'S' and o.operemefut = 'R')),0);
		     					end if;
	     					end if;
		     			end loop;
		     			v_umpetqtd = v_pprquanti;
		     		end if;
		     	end if;
		     	--raise notice 'Aqui 3';
		     	v_procusrep = 0;
		     	select 
		     		coalesce(p.prodpriem,0),
		     		coalesce(p.procusrep, 0),
		     		coalesce(p.profantasm, 'N')
		     		into 
		     		v_prodpriem, 
		     		v_procusrepaux,
		     		v_pfanta
		     	from produto p where p.produto = v_umpetpro;
		     
		     	--if (v_prodpriem > 0) then
		     		v_prjessqte = v_umpetqtd;
		     		v_prjesspre = v_umpetpro;
		     		v_prjessqts = 0;
		     		v_prjesspri = v_priorilote;
		     		v_xpai = v_umpetpro;
		     		--A funcao "fn_subGrava_cria_projeto_expedicao" tem o codigo da Sub-rotina "Grava"
			     	--raise notice 'Aqui 3.1 %, %, %, %, %, %', v_prjesspre, v_parexpcod, v_prjaxped, v_umpetseq, v_xpai, v_umpetpro;
		     		perform fn_subGrava_cria_projeto_expedicao(v_parexsvcus, v_multiempresa, Trim(v_prjesspre), v_deposito, v_procusrepaux, v_prjesparc, 
															   v_prjessqte, v_parexpcod, v_prjaxped, v_umpetseq, v_xpai, v_umpetpro, v_parexssoma,
															   v_parexsvolp, v_prjesspri, v_prjesorcs, v_saldo, v_umpetqtd, v_prjessqts, v_usuario,
															   v_lgaversao);
															  
				  --Assim que realizar a gravacao dentro da funcao "fn_subGrava_cria_projeto_expedicao" vai realizar o processo do objeto P-EXPSI06 para separar a quantidade
			  --Objeto "P-EXPSI98", antes da chamada do "P-EXPSI06"
				--raise notice 'Aqui 4';														  
				select 
					1,
					prjexsi1.PRJESSEPA,  --Codigo do pedido
			        prjexsi1.PRJESSTIP,  --Pedido ou assistencia (nesse caso sera sempre pedido = P)
			        prjexsi1.PRJESSPRO,  --Codigo do produto do pedido
			        prjexsi1.PRJESSPRE,   --Codigo do produto separado
			        prjexsi1.PRJESSPPAI, --Codigo do produto pai do produto separado (nesse caso sera o codigo do produto do pedido tambem)
			        prjexsi1.PRJESSPRI,  --Prioridade de embarque
			        prjexsi1.PRJESSSEQ,  --Sequencia do produto do pedido
			        prjexsi1.PRJESSQTD,  --Quantidade do produto do pedido
			        prjexsi1.PRJESSQTE,  --Quando total do produto separado
			        prjexsi1.PRJESSQTE,  --Quando total do produto separado
			        prjexsi1.prjessqts,  --Quantidade ja separada
			        prjexsi1.prjessorc 
			        into
			        v_existe,
			        v_prjessepa,
			        v_prjesstip,
			        v_prjesspro,
			        v_prjesspre,
			        v_prjessppai,
			        v_prjesspri,
			        v_prjessseq,
			        v_prjessqtd,
			        v_prjessqte,
			        v_prjessqts_aux,
			        v_quanti,
			        v_prjessorc
		        from prjexsi1 prjexsi1 where prjexsi1.prjescodi = v_parexpcod and prjexsi1.prjessepa = v_prjaxped and prjexsi1.prjessseq = v_prjaxseq and prjexsi1.prjessqte > 0 and prjexsi1.prjessqte > prjexsi1.prjessqts;
		       
		        if (v_existe = 1) then
			        select 
			     		p.deposito 
			     		into 
			     		v_deposito
			     	from pedido p where p.pedido = v_prjaxped;
			     
					select coalesce(fn_saldo_produto(current_date, v_prjesspre, v_deposito, 0, 0),0) into v_saldo;
					if (v_saldo < v_prjaxqtsep and v_negativo <> 'S' and v_tipocri = 'N') then
						v_prjaxqtsep = coalesce(v_saldo,0);
					end if;
					--raise notice 'Aqui 5 Produto %, Pedido %, Deposito % ', Trim(v_prjesspre), v_prjaxped, v_deposito;
					if (v_prjaxqtsep <= 0 and v_negativo <> 'S' and v_tipocri = 'N') then
						v_horaatual = current_time::char(8);
						v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
			      		v_horaatual = v_horaatual || ' ' || v_count;
						v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) ||' e Seq.: ' || v_prjaxseq || '. Nao realizada a separacao devido a nao ter saldo no deposito do pedido. Saldo total faltante.';
						insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
								('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
					else
						--Objeto "P-EXPSI06"
						v_procusrep = 0;
						if (v_parexsvcus <> 'N' and v_parexssep = 'S') then
							if (v_multiempresa = 'S') then
								v_procusrep = coalesce((select ccrcus from prodcust p where p.ccrpro = trim(Trim(v_prjesspre)) and p.ccrdep = v_deposito),0); --Deposito de acordo com o do pedido
								--raise notice 'Aqui 5.1 % ', v_procusrep;
							else
								select 
						     		coalesce(p.procusrep, 0)
						     		into 
						     		v_procusrep
						     	from produto p where p.produto = Trim(v_prjesspro);
							end if;
						end if;
						if (v_procusrep = 0 and v_parexsvcus = 'B') then --v_parexsvcus = Validar custo de reposicao nos produtos do projeto, se for igual a C e apenas critica, se nao e bloqueio
							v_horaatual = current_time::char(8);
							v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
				      		v_horaatual = v_horaatual || ' ' || v_count;
							v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(Trim(v_prjesspre)) || ' e Seq.: ' || v_prjaxseq ||'. Nao realizada a separacao devido a nao ter custo de reposicao.';
							insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
									('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
						else
							v_conftrans = 'S';
							v_qtdeaux = v_prjessqts_aux - (v_quanti + v_prjaxqtsep); --Quantidade prevista de separacao menos (a quantidade ja separada mais a quantidade que sera separada)
							v_prjessqts = v_prjaxqtsep;
							--raise notice 'Aqui 5.2 Valida Quantidade % , Parametro %', v_qtdeaux, v_parexssep;
							if (v_qtdeaux >= 0 and v_parexssep = 'S') then
								--Verificacao de negativos
								--raise notice 'Aqui 5.3 Valida Quantidade % , Parametro %', v_negativo, v_parexssnf;
								if (v_negativo <> 'S' and v_parexssnf <> 'N') then
									v_pridata = current_date;
									v_pridata = (select t.pridata from toqmovi t where t.pridata >= current_date and t.priproduto = trim(Trim(v_prjesspre)) and t.pritransac >= 11 order by t.pridata desc, t.priproduto asc limit 1);
									if (v_pridata < current_date or v_pridata is null) then
										v_pridata = current_date;
									end if;
									select coalesce(fn_saldo_produto(v_pridata, Trim(v_prjesspre), v_deposito, 0, 0),0) into v_saldo;
									if (v_parexstra = 'S' and v_saldo < v_qtdeaux and v_tipocri = 'N') then
										v_conftrans = 'N';
										v_qtdetra = v_qtdeaux - v_saldo;
										v_horaatual = current_time::char(8);
										v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
							      		v_horaatual = v_horaatual || ' ' || v_count;
										v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) ||' e Seq.: ' || v_prjaxseq || '. Nao realizada a separacao devido a nao ter saldo no deposito do pedido. Saldo faltante: ' || v_qtdetra;
										insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
												('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
									end if;
								end if;
								--Se tem saldo para o deposito do pedido segue para o proximo passo
								if (v_conftrans = 'S') then
									v_continua = 'S';
								    v_prjv1ordn = coalesce(v_prjessorc, 0);
									v_qtdsep = coalesce(v_quanti,0); --Quantidade ja separada
									--Sub-rotina "Verifica Volumes"
									v_qtdejavol = coalesce((select sum(p.prjv1qtde) from prjvol1 p where p.prjv1codi = v_parexpcod and p.prjv1pedn = v_prjaxped and p.prjv1peds = v_prjaxseq and p.prjv1peas = 'P' and p.prjv1ordn = v_prjv1ordn and p.prjv1qtde > 0),0);
									if ((v_prjessqts + v_quanti) < v_qtdejavol and v_qtdejavol is not null and v_qtdejavol <> 0) then --Caso a quantidade prevista de separacao + o que ja foi separado for menor que a quantidade do volume
										--raise notice 'Aqui 6.1';
										v_horaatual = current_time::char(8);
										v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
							      		v_horaatual = v_horaatual || ' ' || v_count;
										v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: ' || v_prjaxseq || '. Nao realizada a separacao devido a quantidade de volumes ' || v_qtdejavol || ' ser maior que a separada' || v_prjaxqtsep;
										insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
												('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
									else
										select p.prorastre into v_rastreado from produto p where p.produto = Trim(v_prjesspre);
										if (v_rastreado = 'S' and v_parexrast = 'S') then
											v_qtderast = v_prjessqts; --Quantidade a ser separada
											--sub-rotina "Grava Rastreabilidade da Separacao"
											v_prjessrasc = 0;
											v_prjessrase = 1;
											if coalesce((select 1 from prjexsra p where p.prjescodi = v_parexpcod and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_prjaxseq and p.prjessppai = v_prjessppai
											and p.prjesspre = Trim(v_prjesspre) and p.prjessrasc = v_prjessrasc and p.prjessrase = v_prjessrase limit 1),0) <> 1 then
												v_ltrasaldo = coalesce((select l.ltrasaldo from lotrast l where l.ltracodig = trim(v_prjaxrast)),0);
												if (v_ltrasaldo - v_qtderast) > 0 then
													--Caso o registro nao exista, sera criado
													v_prjessrasc = coalesce((select n.notpcontro from notparam n where n.notparam = 1),0);
													update notparam set notpcontro = v_prjessrasc + 1;
													update paramprx set prxcontrol = v_prjessrasc + 1;
													insert into prjexsra (prjescodi, prjessepa, prjessseq, prjesstip, prjessppai, prjesspre, prjessrasc, prjessrase, prjessrqtd, prjesrdtmv, prjesrhrmv, prjesrusmv) values
																		 (v_parexpcod, v_prjaxped, v_prjaxseq, 'P', v_prjessppai, Trim(v_prjesspre), v_prjessrasc, v_prjessrase, v_qtderast, current_date, current_time::char(8), v_usuario);
													
													--Grava rastreabilidade na tabela de rastreabilidade geral
													insert into toqrastr (toqrascon, toqrasseq, toqrasras, toqraspro, toqrasdat, toqrastra, toqrasqtd, toqrasdep) values 
																		 (v_prjessrasc, v_prjessrase, Trim(v_prjaxrast), Trim(v_prjesspre), current_date, 15, v_qtderast, v_deposito);
																		 
													--Atualiza o saldo do lote de rastreabilidade, diminuindo a quantidade utilizada no momento
													update lotrast set ltrasaldo = ltrasaldo - v_qtderast where ltracodig = Trim(v_prjaxrast);
												
													if coalesce((select 1 from prjexsr1 p where p.prjescodi = v_parexpcod and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_prjaxseq and p.prjessppai = v_prjessppai
														and p.prjesspre = Trim(v_prjesspre) and p.prjessrasc = v_prjessrasc and p.prjessrase = v_prjessrase and p.prjesslras = Trim(v_prjaxrast)),0) > 0 then
															update prjexsr1 set prjesslqtd = prjesslqtd + v_qtderast
																where p.prjescodi = v_parexpcod and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_prjaxseq and p.prjessppai = v_prjessppai
																and p.prjesspre = Trim(v_prjesspre) and p.prjessrasc = v_prjessrasc and p.prjessrase = v_prjessrase and p.prjesslras = Trim(v_prjaxrast);
													else
														insert into prjexsr1 (prjescodi, prjessepa, prjesstip, prjessseq, prjessppai, prjesspre, prjessrasc, prjessrase, prjesslras, prjesslqtd) values
																	(v_parexpcod, v_prjaxped, 'P', v_prjaxseq, v_prjessppai, Trim(v_prjesspre), v_prjessrasc, v_prjessrase, Trim(v_prjaxrast), v_qtderast);
													end if;
												else
													v_horaatual = current_time::char(8);
													v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
										      		v_horaatual = v_horaatual || ' ' || v_count;
													v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) ||' e Seq.: ' || v_prjaxseq ||
														    '. Nao realizada a separacao devido a quantidade ' || v_ltrasaldo || ' do lote de rastreabilidade ' || Trim(v_prjaxrast) || ' ser menor que a quantidade a ser separada ' || v_qtderast;
													insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
															('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
														
													v_continua = 'N';
												end if;
											end if;
										end if;
													
										--raise notice 'Aqui 6.2 % ', v_continua;
										if (v_continua = 'S') then
											--Grava Volume
											
											v_prjv2seqe = coalesce((select prjv2seqe from prjvol2 p where p.prjv2codi = v_parexpcod and prjv2cvol = v_prjaxcvol order by p.prjv2codi, p.prjv2seqe desc limit 1),0);
											if (v_prjv2seqe = 0) then
												v_prjv2seqe = coalesce((select prjv2seqe from prjvol2 p where p.prjv2codi = v_parexpcod order by p.prjv2codi, p.prjv2seqe desc limit 1),0);
												v_prjv2seqe = v_prjv2seqe + 1;
											end if;
											v_cprjv2etiq = lpad(v_parexpcod::text,10,'0') || lpad(v_prjv2seqe::text,4,'0');
										
											if coalesce((select 1 from prjvolum p where p.prjvcodig = v_parexpcod limit 1),0) <> 1 then
												insert into prjvolum (prjvcodig, prjvdescr, prjvstatu, prjvseqet) values (v_parexpcod, v_prjaxdvol, 'P', v_prjv2seqe);
													v_horaatual = current_time::char(8);
													v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
										      		v_horaatual = v_horaatual || ' ' || v_count;
													v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || '. Criado o volume ' || v_cprjv2etiq;
													insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
															('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
											end if;
											--raise notice 'Aqui 7';
										
											v_prjv1seqv = coalesce((select prjv1seqv from prjvol1 p where p.prjv1codi = v_parexpcod and p.prjv1pedn = v_prjaxped and p.prjv1peds = v_prjaxseq and prjv1peas = 'P' and
														  p.prjv1ordn = 1 and p.prjv1ordp = Trim(v_prjesspro) order by PRJV1CODI, PRJV1PEDN, PRJV1PEDS, PRJV1ORDN, PRJV1LOTP limit 1),0);
										
											if coalesce((select 1 from prjvol2 p where p.prjv2codi = v_parexpcod and p.prjv2seqe = v_prjv2seqe limit 1),0) <> 1 then
												--OS 4298425 - Add coluna "prjv2pedn"
												insert into prjvol2 (prjv2codi, prjv2seqe, prjv2qtdp, prjv2etiq, prjv2desc, prjv2sepd, prjv2chrmv, prjv2sepu, prjv2peso, prjv2pepr, prjv2obs, prjv2ched, prjv2ehrmv, prjv2cheu, prjv2cvol, prjv2pedn) values
																	(v_parexpcod, v_prjv2seqe, v_prjessqts, v_cprjv2etiq, v_prjaxdvol, current_date, current_time::char(8), v_usuario, v_prjaxpsvol, v_prjaxpsvol, 1, current_date, current_time::char(8), '', v_prjaxcvol, v_prjaxped);
																
													v_horaatual = current_time::char(8);
													v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
										      		v_horaatual = v_horaatual || ' ' || v_count;
													v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', volume: ' || v_cprjv2etiq || ' fechado com o Peso ' || v_prjaxpsvol;
													insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
															('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
											else
												update prjvol2 set prjv2peso = prjv2peso + v_prjaxpsvol, prjv2pepr = prjv2pepr + v_prjaxpsvol where prjv2codi = v_parexpcod and prjv2seqe = v_prjv2seqe;
											end if;
											--raise notice 'Aqui 7.1';		
											
											v_prjv1seqv = v_prjv1seqv + 1;
											--raise notice 'Aqui 7.2 % , %',v_prjv1seqv, v_parexpcod;
											v_saldoRestante = v_prjessqts; --v_prjessqts - v_prjaxqtvol;
											insert into prjvol1 (prjv1codi, prjv1pedn, prjv1peds, prjv1peas, prjv1ordn, prjv1seqv, prjv1lotp, prjv1ordp, prjv1qtdo, prjv1pedp, prjv1saldo, prjv1seqe, prjv1qtde,
																prjv1ppai, prjv1qtdr, prjv1core, prjv1sere) values
																(v_parexpcod, v_prjaxped, v_prjaxseq, 'P', 1, v_prjv1seqv, '', trim(v_prjesspre), v_prjessqts, Trim(v_prjesspro), v_saldoRestante, v_prjv2seqe, v_prjaxqtvol,
																v_prjessppai, v_prjaxqtde, 0, 0);
												
													v_horaatual = current_time::char(8);
													v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
										      		v_horaatual = v_horaatual || ' ' || v_count;
													v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: '  || v_prjaxseq ||
												    '. Incluido no volume ' || v_cprjv2etiq;
													insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
															('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
											
											--raise notice 'Aqui 7.3';
											--Faz movimento de transferencia
											if (v_parexssep = 'S') then
												v_notpcontro = coalesce((select n.notpcontro from notparam n where n.notparam = 1),0);
												update notparam set notpcontro = v_notpcontro + 1;
												update paramprx set prxcontrol = v_notpcontro + 1;
												v_exprojeto = 'EX' || v_parexpcod;
												insert into toqmovi (itecontrol, prisequen, pridocto, prideposit, pritransac, pridata, priordem, priproduto, priquanti, operacao) values
																    (v_notpcontro, 1, v_exprojeto, v_deposito, 15, current_date, 0, Trim(v_prjesspre), v_prjessqts, 'TRANSFER');
																   
												    v_horaatual = current_time::char(8);
													v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
										      		v_horaatual = v_horaatual || ' ' || v_count;
												    v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: ' || v_prjaxseq ||
												    '. Inclusao TRANF. EXPEDICAO Deposito Origem ' || v_deposito || ', Produto ' || Trim(v_prjesspre) || ', Qtde ' || v_prjessqts || ', Controle ' || v_notpcontro || ', em ' || current_date;
													insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
															('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
														
												--raise notice 'Aqui 7.4';
												insert into toqmovi (itecontrol, prisequen, pridocto, prideposit, pritransac, pridata, priordem, priproduto, priquanti, operacao) values
																    (v_notpcontro, 500, v_exprojeto, v_parexsdet, 5, current_date, 0, Trim(v_prjesspre), v_prjessqts, 'TRANSFER');
														
												    v_horaatual = current_time::char(8);
													v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
										      		v_horaatual = v_horaatual || ' ' || v_count;
											    	v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: ' || v_prjaxseq ||
												    '. Inclusao TRANF. EXPEDICAO Deposito Destino ' || v_parexsdet || ', Produto ' || Trim(v_prjesspre) || ', Qtde ' || v_prjessqts || ', Controle ' || v_notpcontro || ', em ' || current_date;
													insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
															('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
														
												insert into prjexsi3 (prjescodi, prjessepa, prjesstip, prjessseq, prjesspre, prjemscont, prjemsqte, prjemdata, prjessppai, prjemhrmv, prjemusmv) values
																	 (v_parexpcod, v_prjaxped, 'P', v_prjaxseq, Trim(v_prjesspre), v_notpcontro, v_prjessqts, current_date, v_prjessppai, current_time::char(8), v_usuario);
													v_horaatual = current_time::char(8);
													v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
										      		v_horaatual = v_horaatual || ' ' || v_count;
													v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: ' || v_prjaxseq ||
												    '. Inclusao do Movimento de Expedicao.';
													insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
															('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
												--raise notice 'Aqui 7.5';
											end if;
											--raise notice 'Aqui 8';
											--Atualiza informcaoes de quantidade do registro de separacao
											if (v_prjessqts = v_prjessqte) then
												v_prjesscon = 1;
											else
												v_prjesscon = 0;
											end if;
											-- OS 4298425, add "prjessqem = prjessqts + v_prjessqts" que se refere a quantidade embarcada
											update prjexsi1 set prjessqts = prjessqts + v_prjessqts, prjessqem = prjessqts + v_prjessqts, prjesscon = v_prjesscon, prjesstop = 1, prjessdtmv = current_date, prjesshrmv = current_time::char(8), prjessusmv = v_usuario
											where prjescodi = v_parexpcod and prjessepa = v_prjaxped and prjesstip = 'P' and prjessseq = v_prjaxseq and prjessppai = trim(v_prjessppai) and prjesspre = trim(v_prjesspre);
										
											--raise notice '%, %, %, %, %', v_prjaxcont, v_prjaxproj, v_prjaxped, v_prjaxseq, v_prjaxprd;
											--OS 4298425
											select p.prjesesem, p.prjeseorc into v_prjesesem, v_prjeseorc from prjexsi2 p where prjescodi = v_parexpcod and prjesempa = v_prjaxped and prjesetip = 'P' and prjeseseq = v_prjaxseq and prjesepre = v_prjesspre and prjeseppai = v_prjessppai order by prjesesem desc limit 1;
											v_prjesesem = coalesce(v_prjesesem,0) + 1;
										    v_prjeseorc = coalesce(v_prjeseorc,0) + 1;
										    --v_prjesesem = coalesce(v_prjesesem,0) + 1; --Como sempre vai ser um novo embarque, incrementa toda vez.
										    --v_prjeseorc = coalesce(v_prjeseorc,0) + 1; --Como sempre vai ser um novo embarque, incrementa toda vez.
										
											--Grava o embarque (Objeto P-EXPSI07)
											v_horaatual = current_time::char(8);
											insert into prjexsi2 (prjescodi, prjesempa, prjesetip, prjeseseq, prjesepro, prjesepre, prjesesem, prjesepri, prjeseqte, prjeseemb, prjesepla, prjesefat, prjeseorc, 
																  prjeseqpv, prjesedtmv, prjesehrmv, prjeseusmv, prjeseppai, prjesecon)
																  values
																  (v_parexpcod, v_prjaxped, 'P', v_prjaxseq, v_prjesspro, v_prjesspre, v_prjesesem, v_prjesspri, v_prjessqts, v_cprjv2etiq, '', 0, v_prjeseorc,
																   v_prjessqte, v_dataatual, v_horaatual, v_usuario, v_prjessppai, v_prjesscon);
																  
											v_horaatual = current_time::char(8);
											v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
								      		v_horaatual = v_horaatual || ' ' || v_count;
											v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: ' || v_prjaxseq ||
										    '. Inclusao do Embarque.';
											insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
													('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
																  
												
											--Grava etiqueta da separacao
											v_horaatual = current_time::char(8);
											if (select 1 from prjexsi7 p2 where prjescodi = v_parexpcod and prjessepa = v_prjaxped and prjesstip = 'P' and prjessseq = v_prjaxseq and prjessppai = v_prjessppai and prjesspre = v_prjesspre and prjessetiq = v_cprjv2etiq) > 0 then
												update prjexsi7 set prjessetqt = prjessetqt + v_prjessqts, prjessedtm = v_dataatual, prjessehrm = v_horaatual, prjesseusm = v_usuario where prjescodi = v_parexpcod and prjessepa = v_prjaxped and prjesstip = 'P' and prjessseq = v_prjaxseq and prjessppai = v_prjessppai and prjesspre = v_prjesspre and prjessetiq = v_cprjv2etiq;
											else
												insert into prjexsi7 (prjescodi, prjessetli, prjessepa, prjesstip, prjessseq, prjessppai, prjesspre, prjessetiq, prjessetqt, prjessedtm, prjessehrm, prjesseusm)					 
																	 values
																	 (v_parexpcod, 'S', v_prjaxped, 'P', v_prjaxseq, v_prjessppai, v_prjesspre, v_cprjv2etiq, v_prjessqts, v_dataatual, v_horaatual, v_usuario);
											end if;
											
											v_horaatual = current_time::char(8);
											v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
								      		v_horaatual = v_horaatual || ' ' || v_count;
											v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: ' || v_prjaxseq ||
										    '. Criacao da Etiqueta de Separacao.';
											insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
													('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
												
										    --Grava as etiquetas do embarque (sub-rotina "Grava Etiq Volume" do objeto "P-EXPSI07")
											v_horaatual = current_time::char(8);
											insert into prjexsi8 (prjescodi, prjesempa, prjesetip, prjeseseq, prjeseppai, prjesepre, prjesesem, prjeseetiq, prjeseetqt, prjeseetli, prjeseedtm, prjeseehrm, prjeseeusm)
																  values
																  (v_parexpcod, v_prjaxped, 'P', v_prjaxseq, v_prjessppai, v_prjesspre, v_prjesesem, v_cprjv2etiq, v_prjessqts, 'S', v_dataatual, v_horaatual, v_usuario);
													 
											v_horaatual = current_time::char(8);
											v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
								      		v_horaatual = v_horaatual || ' ' || v_count;
											v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: ' || v_prjaxseq ||
										    '. Criacao da Etiqueta de Embarque.';
											insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
													('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
																											 
											--
											new.prjaxmov = 2;
										
											update prjexsim set prjesstat = 'A' where prjescodi = v_parexpcod;
										end if;
									end if;
								end if;
								--raise notice 'Aqui 9';
							else
								--raise notice 'Aqui 10';
								if (v_qtdeaux < 0) then
										v_horaatual = current_time::char(8);
										v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
							      		v_horaatual = v_horaatual || ' ' || v_count;
										v_log = 'Integracao MasterLink/Smart WMS. Projeto de Expedicao: ' || v_parexpcod || ', Pedido: ' || v_prjaxped || ', Produto: ' || Trim(v_prjesspre) || ' e Seq.: ' || v_prjaxseq ||
											'. Nao realizada a separacao devido a quantidade a ser separada ' || v_prjessqts || ' + quantidade ja separada ' || v_quanti || ' ser maior que o previsto de separacao' || v_prjessqte;
										insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
												('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
								end if;
							end if;
						end if;
					end if;
				end if;
		else
			if coalesce((select 1 from pedprodu p where p.pedido = v_prjaxped and p.pprseq = v_prjaxseq and p.pprproduto = v_prjaxprd limit 1),0) <> 1 then
				v_horaatual = current_time::char(8);
				v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
	      		v_horaatual = v_horaatual || ' ' || v_count;
				v_log = 'Integracao MasterLink/Smart WMS. Pedido de Venda ' || v_prjaxped || ', Sequencia ' || v_prjaxseq || ', Produto ' || v_prjaxprd || '. Nao existe no ERP.';
				insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
									('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
			end if;
			
			if coalesce((select 1 from lotrast l where l.ltracodig = Trim(v_prjaxrast) and l.ltraprodu = v_prjaxprd limit 1),0) <> 1 then
				v_horaatual = current_time::char(8);
				v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
	      		v_horaatual = v_horaatual || ' ' || v_count;
				v_log = 'Integracao MasterLink/Smart WMS. Lote de Rastreabilidade ' || Trim(v_prjaxrast) || ' para o Produto ' || v_prjaxprd || ' nao existe no ERP.';
				insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
									('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
			end if;
		end if;
	--end loop;
	end if;
	return new;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_cria_projeto_expedicao() SET search_path=public, pg_temp;

ALTER FUNCTION fn_cria_projeto_expedicao()
  OWNER TO postgres;
