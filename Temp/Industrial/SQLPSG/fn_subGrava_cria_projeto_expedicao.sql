-- Function: fn_subgrava_cria_projeto_expedicao(character, character, text, numeric, numeric, character, numeric, numeric, numeric, numeric, text, text, character, character, numeric, numeric, numeric, numeric, numeric, text, text)

-- DROP FUNCTION fn_subgrava_cria_projeto_expedicao(character, character, text, numeric, numeric, character, numeric, numeric, numeric, numeric, text, text, character, character, numeric, numeric, numeric, numeric, numeric, text, text);

CREATE OR REPLACE FUNCTION fn_subgrava_cria_projeto_expedicao(v_parexsvcus character, v_multiempresa character, v_prjesspre text, v_deposito numeric, v_procusrepaux numeric, v_prjesparc character, v_prjessqte numeric, v_parexpcod numeric, v_prjaxped numeric, v_umpetseq numeric, v_xpai text, v_umpetpro text, v_parexssoma character, v_parexsvolp character, v_prjesspri numeric, v_prjesorcs numeric, v_saldo numeric, v_umpetqtd numeric, v_prjessqts numeric, v_usuario text, v_lgaversao text)
  RETURNS void AS
$BODY$
DECLARE
	v_procusrep numeric;
	v_existe numeric;
	v_prjesspritab numeric;
	v_saldoaux numeric;
 	v_log text;
 	v_horaatual text;
 	v_count numeric;
begin
	--Sub-rotina "Grava"
	if (v_parexsvcus <> 'N') then
		--Busca custo de reposicao conforme objeto P-BUSCUSREP
		if (v_multiempresa = 'S') then
			v_procusrep = coalesce((select p.ccrcus from prodcust p where p.ccrpro = v_prjesspre and p.ccrdep = v_deposito),0); --Deposito de acordo com o do pedido
		else
			v_procusrep = v_procusrepaux;
		end if;
	end if;
	if (v_prjesparc = 'S') then --sub-rotina "Outro Projeto"
		v_prjessqte = v_prjessqte - coalesce((select sum(prjessqts) from prjexsi1 p 
									 inner join prjexsim p2 on p.prjescodi = p2.prjescodi 
									 where p.prjescodi <> v_parexpcod and p.prjesspre = v_prjesspre and p.prjessepa = v_prjaxped
									 and p.prjessseq = v_umpetseq and p.prjesstip = 'P' and p.prjessppai = v_xpai and p.prjesspro = v_umpetpro and p2.prjesparc = 'S'),0);
	end if;
	--raise notice '% ', v_parexssoma;
	if (v_parexssoma = 'S') then
		if (v_parexsvolp = 'S') then
			select 
				1,
				p.prjesspri 
				into
				v_existe,
				v_prjesspritab
			from prjexsi1 p where p.prjescodi = v_parexpcod and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_umpetseq and p.prjessppai = v_xpai and p.prjesspre = v_prjesspre limit 1;
		else
			select 
				1,
				p.prjesspri 
				into 
				v_existe,
				v_prjesspritab
			from prjexsi1 p where p.prjescodi = v_parexpcod and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_umpetseq and p.prjesspre = v_prjesspre limit 1;
		end if;
		if (coalesce(v_existe,0) = 1) then
			--caso exista, atualiza
			if (v_prjesspritab > v_prjesspri) then
				v_prjesspritab = v_prjesspri;
			end if;
			update prjexsi1 set prjesspri = v_prjesspritab, prjessqte = prjessqte + v_prjessqte, prjessqts = prjessqts + v_prjessqts
				where p.prjescodi = v_parexpcod and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_umpetseq and p.prjesspre = v_prjesspre;
		else
			--caso nao exista, cria o registro. Nesse caso, o produto do pedido e o mesmo produto que vai poder ser separado, logo, gravamos direto o v_xpai, sem precisar verificar o
			--parametro v_parexsvolp
			v_prjesorcs = v_prjesorcs + 1;
			if (v_prjesparc = 'S') then
				v_saldoaux = v_saldo;
			else
				v_saldoaux = v_umpetqtd;
			end if;
			insert into prjexsi1 (prjescodi, prjessepa, prjesstip, prjessseq, prjessppai, prjesspro, prjessqtd, prjesspre, prjesspri, prjessqte, prjessqts, prjessorc, prjesscon, prjesstop) values
								 (v_parexpcod, v_prjaxped, 'P', v_umpetseq, v_xpai, v_umpetpro, v_saldoaux, v_prjesspre, v_prjesspri, v_prjessqte, v_prjessqts, v_prjesorcs, 0, 1);
								
			v_horaatual = current_time::char(8);
			v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
      		v_horaatual = v_horaatual || ' ' || v_count;
			v_log = 'Incluido Projeto ' || v_parexpcod || ' Ped/Ass: Pedido P/A: P Seq.: ' || v_umpetseq || ' Produto Emb: ' || v_prjesspre;
			insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
						('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
					
			update prjexsim set prjesorcs = v_prjesorcs where prjescodi = v_parexpcod;
		end if;
	else
		v_existe = 0;
		select 1 into v_existe from prjexsi1 p where p.prjescodi = v_parexpcod and p.prjessepa = v_prjaxped and p.prjesstip = 'P' and p.prjessseq = v_umpetseq and p.prjessppai = trim(v_xpai) and p.prjesspre = trim(v_prjesspre) limit 1;
		if (coalesce(v_existe,0) <> 1) then --Caso ja exista nao cria para nao ocorrer erro de chave duplicada
			v_prjesorcs = v_prjesorcs + 1;
			if (v_prjesparc = 'S') then
				v_saldoaux = v_saldo;
			else
				v_saldoaux = v_umpetqtd;
			end if;
			insert into prjexsi1 (prjescodi, prjessepa, prjesstip, prjessseq, prjessppai, prjesspro, prjessqtd, prjesspre, prjesspri, prjessqte, prjessqts, prjessorc, prjesscon, prjesstop) values
								 (v_parexpcod, v_prjaxped, 'P', v_umpetseq, v_xpai, v_umpetpro, v_saldoaux, v_prjesspre, v_prjesspri, v_prjessqte, v_prjessqts, v_prjesorcs, 0, 1);
						
			v_horaatual = current_time::char(8);
			v_count = (SELECT count(*) + 1 FROM logaces WHERE lgaorigem = 'EXPEDICAO' AND lgadata = current_date AND lgahora >= v_horaatual);
      		v_horaatual = v_horaatual || ' ' || v_count;
			 
			v_log = 'Incluido Projeto ' || v_parexpcod || ' Ped/Ass: Pedido P/A: P Seq.: ' || v_umpetseq || ' Produto Emb: ' || v_prjesspre;
			insert into logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao) values 
						('EXPEDICAO', current_date, v_horaatual, v_usuario, v_log, v_lgaversao);
					
			update prjexsim set prjesorcs = v_prjesorcs where prjescodi = v_parexpcod;
		end if;
	end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_subgrava_cria_projeto_expedicao(character, character, text, numeric, numeric, character, numeric, numeric, numeric, numeric, text, text, character, character, numeric, numeric, numeric, numeric, numeric, text, text) SET search_path=public, pg_temp;

ALTER FUNCTION fn_subgrava_cria_projeto_expedicao(character, character, text, numeric, numeric, character, numeric, numeric, numeric, numeric, text, text, character, character, numeric, numeric, numeric, numeric, numeric, text, text)
  OWNER TO postgres;
