-- Function: fn_inicio_mrpii(numeric, character, character, character, character, date, date, numeric, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, numeric, character, character, character, character, character, character, character, character, numeric, text, date, date, numeric, character, character)

-- DROP FUNCTION fn_inicio_mrpii(numeric, character, character, character, character, date, date, numeric, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, numeric, character, character, character, character, character, character, character, character, numeric, text, date, date, numeric, character, character);

CREATE OR REPLACE FUNCTION fn_inicio_mrpii(p_plano numeric, p_paraemule character, p_usuario_logado character, p_mulemp character, p_descplano character, p_dtini date, p_dtfim date, p_acuplano numeric, p_tiplano character, p_pmfnecseg character, p_pmfsldest character, p_pmfordens character, p_pmfreserv character, p_pmfpedido character, p_pmfsaiben character, p_pmfentben character, p_pmfsaicon character, p_pmfentcon character, p_pmcnecseg character, p_pmcsldest character, p_pmccompra character, p_pmcreserv character, p_pmcsaiben character, p_pmcentben character, p_pmcsaicon character, p_pmcentcon character, p_pmfloteco character, p_pmcloteco character, p_deposito numeric, p_pmflotema character, p_pmcpedido character, p_pmfselpm character, p_pmfpmestr character, p_pmcassiste character, p_pmfasstec character, p_pmflotemu character, p_pmclotemu character, p_ppldelay numeric, deposito_texto text, p_dataini date, p_datafim date, p_plamcodig numeric, p_pmpfirme character, p_utilizaoc character, p_reatro character)
  RETURNS void AS
$BODY$
DECLARE
	rec record;
	sldestoq numeric;
    sldpedven numeric;
    sldminimo numeric;
    sldreserva numeric;
    sldcompra numeric;
    sldnecess numeric;
    sldpende numeric;
    sldfinal numeric;
    plano numeric;
    planonegativo numeric;
    prxplano numeric;
    qtdedepobase numeric;
    qtdedepoplano numeric;
    todos character;
   	pmflotemu character;
   	pmclotemu character;
    data_atual date;
    hora_atual text;
    --vprosldmin numeric;
    dataini date;
    datafim date;
    vmpscodpla numeric;
    prodnomps character;
    qtdcompra numeric;
   	qtdreserv numeric;
   	qtdtmpcmp numeric;
   	qtdtmpres numeric;
   	qtdfinal numeric;
   	dtperifim date;
   	qtdneces numeric;
   	multipli numeric;
   	sldcompra1 numeric;
   	vpmsabado character;
   	vpmdomingo character;
   	rec2 record;
   	vrec2pln2neces numeric;
	vrec2pln2sldre numeric;
	vrec2pln2sldin numeric;
	vrec2pln2sltex numeric;
	saldoini numeric;
	rec3 record;
	nececalen numeric;
	deposito_array int[];  -- Sergio - OS 4173424 - 26/09/24
	gravar numeric;
	contador numeric;
begin
	--raise notice 'Inicio';
	
	plano = p_plano;
	pmflotemu = p_pmflotemu;
	pmclotemu = p_pmclotemu;
	data_atual = current_date;
	hora_atual = substring(current_time::text,1,8);

	-- Sergio - OS 4185124 - 28/10/24
	drop table if exists planee_tmp;
	drop table if exists planei_tmp;
	create temporary table planee_tmp (like planece including all);
	create temporary table planei_tmp (like planecii including all);

	if plano > 0 then
		--raise notice 'Vai inserir na temp1';
		insert into Planee_tmp 
			select * from planece where planece.plncodigo = plano ;
		
		delete from planece where planece.plncodigo = plano;
		
		--raise notice 'Vai inserir na temp2';
		insert into planei_tmp  
			select * from planecii where planecii.pln2codig = plano;
		delete from planecii where planecii.pln2codig = plano;
		--raise notice 'Feito, vai processar dados';
	end if;




	--if plano > 0 then
	--	select count(*) into qtdedepobase from deposito;
	--	select count(*) into qtdedepoplano from planosde where placodigo = plano;
	--	todos = 'S';
	--	if qtdedepobase <> qtdedepoplano then
	--		todos := 'N';
	--	end if;
	--end if;

	--if plano = 0 then
		--prxplano := 0;
	
		--select
		--	PMULTPLANO into prxplano
		--from parampla p2 where p2.pmplacont = 1;
		
		--prxplano := prxplano + 1;
		--if prxplano is null then
		--	prxplano = 1;
		--end if;
	
		--update parampla set PMULTPLANO = prxplano where pmplacont = 1;
		--update parampla set PMULTPLANO = plano where pmplacont = 1;
	
	    --plano := prxplano;
		deposito_texto := nullif(deposito_texto,'');	
		deposito_texto := coalesce(deposito_texto,'0');
		
		deposito_array = (string_to_array(deposito_texto, ',')::smallint[]);  -- Sergio - OS 4173424 - 26/09/24
		
	    planonegativo = plano * (-1);
	   
	    if (select count(*) from planos where placodigo = plano) > 0 then
	    else
		    insert into planos (placodigo, pladescri, pladtini, pladtfim, plaacumu, platippl, pladtcal, plfnecseg, plfsldest, plfordens, plfreserv, plfpedido, plfsaiben, plfentben, 
		    plfsaicon, plfentcon, plcnecseg, plcsldest, plccompra, plcreserv, plcsaiben, plcentben, plcsaicon, plcentcon, plcloteco, plfloteco, plsituaca, plaordlis, pladeposi,
		    plflotema, plahorag, plausua, plcpedido, plfselpm, plfpmestr, plcassiste, plfassiste, plflotemu, plclotemu, pldelay, pladtcon, plreatro)
		    values (plano, p_descplano, p_dtini, p_dtfim, p_acuplano, p_tiplano, data_atual, p_pmfnecseg, p_pmfsldest, p_pmfordens, p_pmfreserv, p_pmfpedido, p_pmfsaiben, p_pmfentben, p_pmfsaicon, p_pmfentcon, 
		            p_pmcnecseg, p_pmcsldest, p_pmccompra, p_pmcreserv, p_pmcsaiben, p_pmfentben, p_pmcsaicon, p_pmfentcon, p_pmcloteco, p_pmfloteco, '0', planonegativo, p_deposito, p_pmflotema, hora_atual, 
		            p_usuario_logado, p_pmcpedido, p_pmfselpm, p_pmfpmestr, p_pmcassiste, p_pmfasstec, p_pmflotemu, p_pmclotemu, p_ppldelay, '0001-01-01', p_reatro);
        
	       	if p_mulemp = 'S' then
	       		insert into planosde (placodigo, pladepdep)
					select 
						plano,
						d.deposito 
					from deposito d 
					where (deposito_array = '{}'::int[]   OR d.deposito = ANY(deposito_array)) ;--string_to_array(deposito_array, ',')::smallint[])); Sergio - OS 4173424 - 26/09/24
			end if;
       	end if;
       select count(*) into qtdedepobase from deposito;
	   select count(*) into qtdedepoplano from planosde where placodigo = plano;
	   todos = 'S';
	   if qtdedepobase <> qtdedepoplano then
	   		todos := 'N';
	   end if;
	
	if pmflotemu is null or pmflotemu = '' then
		pmflotemu := 'N';
	end if;
	
	if pmclotemu is null or pmclotemu = '' then
		pmclotemu := 'N';
	end if;

	dataini = p_dataini;
	datafim = p_datafim;

	qtdreserv = 0;
	qtdcompra = 0;

	for rec in
		select 
			p.produto as pproduto,
			p.profantasm as profanta,
			p.proorigem as tpprodu,
			p.prosldmin as vprosldmin,
			p.grupo as pgrupo,
			p.subgrupo as subgr,
			p.pronome as vpronome,
			p.proplest as propoli,
			p.pronivelb as pronivel,
			p.unimedida as punimed,
			p.protemrep as tmprepo,
			p.proarres as vproarres,
			p.proartol as vproartol,
			p.proloteco as vproloteco,
			p.prolotmul as vprolotmul
		from produto p 
		where p.proplest <> 'MTO' and p.prostatus <> 'I'
		order by p.pronivelb, p.proplest, p.prostatus 
	loop
		sldestoq   = 0;
        sldpedven  = 0;
        sldminimo  = 0;
        sldreserva = 0;
        sldcompra  = 0;
        sldnecess  = 0;
        sldpende   = 0;
        sldfinal   = 0;
	
		select 
			p.plnnecess into sldpende
		from planee_tmp p   -- Sergio - OS 4185124 - 28/10/24 
		where p.plncodigo = plano and p.plnprodut = rec.pproduto;
		
		
		sldpende := coalesce(sldpende,0);		
		
		if rec.profanta = 'S' then
			sldfinal := sldpedven + sldpende;
			sldnecess = sldpedven + sldpende;
		else
			If ( p_pmfnecseg = 'S' And rec.tpprodu = 'F' ) Or ( p_pmcnecseg = 'S' And rec.tpprodu = 'C' ) then
				if (p_paraemule = 'S') then
					if (p_deposito = 0 and todos <> 'S' and p_mulemp = 'S') then
						sldminimo := (select fn_saldo_minimo_geral(rec.pproduto, deposito_texto));
					else
						select 
							p.slminqtd into sldminimo
						from prodminl p 
						where p.slminprod = rec.pproduto and p.slmindep  = p_deposito;
					end if;
				else
					sldminimo := rec.vprosldmin;
				end if;
			end if;
		
			sldminimo := coalesce(sldminimo,0);	
			
		
			vmpscodpla := 0;
			select 
				m.mpscodpla into vmpscodpla
			from mpsmrp m 
			where m.mpsdtinic >= dataini and m.mpsdtinic <= datafim and m.mpscodpro = rec.pproduto and m.mpscodpla = p_plamcodig;
			prodnomps := 'N';
			if vmpscodpla <> 0 then
				prodnomps := 'S';
			end if;
		
			sldestoq := 0;
			If (p_pmpfirme = 'N') or (p_pmpfirme = 'S' and prodnomps = 'N') then
				If (p_pmfsldest = 'S' And rec.tpprodu = 'F') Or (p_pmcsldest = 'S' And  rec.tpprodu = 'C') then
					if (rec.pgrupo = 999) then
						sldestoq := 0;
					else
						if (p_deposito = 0 and todos <> 'S' and p_mulemp = 'S') then
							sldestoq := (select fn_saldo_produto_geral(data_atual, rec.pproduto, deposito_texto, 0, 0));
						else
							sldestoq := (select fn_saldo_produto(data_atual, rec.pproduto, deposito_texto::numeric, 0, 0));
						end if;
					end if;
				end if;
			end if;
		
			sldestoq := coalesce(sldestoq,0);
		
					
			if (rec.tpprodu = 'F' And p_pmfordens = 'S') then
				If (p_pmpfirme = 'N') or (p_pmpfirme = 'S' and prodnomps = 'N') then
					qtdfinal := 0;
					qtdcompra = 0;
				    qtdneces  = 0;
				    qtdreserv = 0;
				    qtdtmpcmp = 0;
				    qtdtmpres = 0;
				    sldcompra1 := sldcompra;
				   
					--Busca as Informacoes de OFs
					qtdcompra := qtdcompra + fn_busca_infos_mrpii('O', deposito_array, p_mulemp, rec.pproduto, plano, rec.vpronome, rec.tpprodu, rec.propoli, rec.profanta, rec.pronivel, rec.pgrupo, rec.subgr,
					                                           rec.punimed, sldnecess, sldcompra1, 0, qtdtmpcmp, qtdtmpres, qtdfinal, '1'::character, p_utilizaoc, rec.tmprepo, sldestoq, p_dataini, 
					                                           p_datafim, sldminimo, sldcompra1);
					                                          
                    sldcompra := sldcompra + qtdcompra;
                end if;
               
               qtdfinal := 0;
			   qtdcompra = 0;
			   qtdneces  = 0;
			   qtdreserv = 0;
			   qtdtmpcmp = 0;
			   qtdtmpres = 0;
               --Busca as Informacoes de Compras
               qtdcompra := qtdcompra + fn_busca_infos_mrpii('C', deposito_array, p_mulemp, rec.pproduto, plano, rec.vpronome, rec.tpprodu, rec.propoli, rec.profanta, rec.pronivel, rec.pgrupo, rec.subgr,
					                                           rec.punimed, qtdneces, 0, 0, qtdtmpcmp, qtdtmpres, qtdfinal, '1'::character, p_utilizaoc, rec.tmprepo, sldestoq, p_dataini, 
					                                           p_datafim, sldminimo, 0);
					                                          
               sldcompra := sldcompra + qtdcompra;
			end if;
		
			if (rec.tpprodu = 'C' And p_pmccompra = 'S') then
				--Busca as Informacoes de Compras
			   qtdfinal := 0;
			   qtdcompra = 0;
			   qtdneces  = 0;
			   qtdreserv = 0;
			   qtdtmpcmp = 0;
			   qtdtmpres = 0;
               qtdcompra := qtdcompra + fn_busca_infos_mrpii('C', deposito_array, p_mulemp, rec.pproduto, plano, rec.vpronome, rec.tpprodu, rec.propoli, rec.profanta, rec.pronivel, rec.pgrupo, rec.subgr,
					                                           rec.punimed, qtdneces, 0, 0, qtdtmpcmp, qtdtmpres, qtdfinal, '1'::character, p_utilizaoc, rec.tmprepo, sldestoq, p_dataini, 
					                                           p_datafim, sldminimo, 0);
					                                          
               sldcompra := sldcompra + qtdcompra;
               
               if p_pmfordens = 'S' then
               		If (p_pmpfirme = 'N') or (p_pmpfirme = 'S' and prodnomps = 'N') then
               			qtdfinal := 0;
					    qtdcompra = 0;
					    qtdneces  = 0;
					    qtdreserv = 0;
					    qtdtmpcmp = 0;
					    qtdtmpres = 0;
					    sldcompra1 := sldcompra;
               			--Busca as Informacoes de OFs
						qtdcompra := qtdcompra + fn_busca_infos_mrpii('O', deposito_array, p_mulemp, rec.pproduto, plano, rec.vpronome, rec.tpprodu, rec.propoli, rec.profanta, rec.pronivel, rec.pgrupo, rec.subgr,
					                                           rec.punimed, sldnecess, sldcompra1, qtdreserv, qtdtmpcmp, qtdtmpres, qtdfinal, '1'::character, p_utilizaoc, rec.tmprepo, sldestoq, p_dataini, 
					                                           p_datafim, sldminimo, sldcompra1);
					                                          
                  	    sldcompra := sldcompra + qtdcompra;
               		end if;
               end if;
			end if;
		
			If ( rec.tpprodu = 'F' And p_pmfreserv = 'S' ) Or ( rec.tpprodu = 'C' And p_pmcreserv = 'S' ) then
				qtdfinal := 0;
			    qtdcompra = 0;
			    qtdneces  = 0;
			    qtdreserv = 0;
			    qtdtmpcmp = 0;
			    qtdtmpres = 0;
                --Caso considera as reservas para produtos fabricados ou comprados
                qtdreserv := qtdreserv + fn_busca_infos_mrpii('R', deposito_array, p_mulemp, rec.pproduto, plano, rec.vpronome, rec.tpprodu, rec.propoli, rec.profanta, rec.pronivel, rec.pgrupo, rec.subgr,
					                                           rec.punimed, sldnecess, 0, 0, qtdtmpcmp, qtdtmpres, qtdfinal, '1'::character, p_utilizaoc, rec.tmprepo, sldestoq, p_dataini, 
					                                           p_datafim, sldminimo, 0);
					                                          
              	sldreserva := sldreserva + qtdreserv;
                
            end if;
           
           sldnecess := sldpedven + sldpende;
           if (rec.vproarres = 'S' and rec.tpprodu = 'F') then
           		if mod(sldnecess,1) <> 0 then
           			if (sldnecess < 1) then
           				sldnecess := 1;
       				else
       					if sldnecess > (TRUNC(sldnecess) + rec.vproartol) then
       						sldnecess := sldnecess + 1;
       					end if;
       					sldnecess := TRUNC(sldnecess);
           			end if;
           		end if;
           end if;
          
           sldfinal := (sldnecess + sldminimo + sldreserva) - (sldestoq + sldcompra);
           if sldfinal > 0 then
           		if ( ( rec.tpprodu = 'F' And p_pmfloteco = 'S' ) Or ( rec.tpprodu = 'C' And p_pmcloteco = 'S'  ) ) And rec.vproloteco > 0 then
           			if (sldfinal < rec.vproloteco) then
           				sldfinal := rec.vproloteco;
           			end if;
           		end if;
           	
           		If ( ( rec.tpprodu = 'F' And p_pmflotemu = 'S' ) Or ( rec.tpprodu = 'C' And p_pmclotemu = 'S'  ) ) And rec.vprolotmul > 0 then
           			if sldfinal < rec.vprolotmul then
           				sldfinal := rec.vprolotmul;
       				else
       					multipli = (sldfinal / rec.vprolotmul) + 0.99;
       					multipli = TRUNC(multipli);
       					sldfinal = rec.vprolotmul * multipli;
           			end if;
           		end if;
           end if;
		end if;
		
		sldnecess := sldnecess - sldpende;
		if (rec.vproarres = 'S' and rec.tpprodu = 'F') then
			if mod(sldfinal,1) <> 0 then
       			if (sldfinal < 1) then
       				sldfinal := 1;
   				else
   					if sldfinal > (TRUNC(sldfinal) + rec.vproartol) then
   						sldfinal := sldfinal + 1;
   					end if;
   					sldfinal := TRUNC(sldfinal);
       			end if;
       		end if;
		end if;
	     
		Perform fn_grava_necessidade_mrpii17(plano, rec.pproduto, rec.tpprodu, rec.punimed, sldnecess, sldestoq, sldminimo, sldcompra, sldfinal, sldreserva, '1'::character, rec.vpronome, rec.propoli, rec.profanta, rec.pronivel,
		                                   rec.pgrupo, rec.subgr);
		gravar = 0;                 
        --Deve ser limpo quando for menor que zero (baseado no objeto PMRPII17 que retorna a informacao ja na funcao nao retornamos ela)
        sldfinal := coalesce(sldfinal,0);
		if (sldfinal) < 0 then
        	sldfinal := 0;
        end if;
        
		--Chamar o PMRPII04
       	vpmsabado := 'N';
        vpmdomingo := 'N';
       	select 
       		p.pmsabado,
       		p.pmdomingo
       		into 
       		vpmsabado,
       		vpmdomingo
       	from parampla p where p.pmplacont = 1;
       
        if length(trim(vpmsabado)) = 0 then
        	vpmsabado = 'N';
        end if;
       
       	if length(trim(vpmdomingo)) = 0 then
        	vpmdomingo = 'N';
        end if;
       

       
        perform fn_processa_necessidades_periodomrpii(plano, rec.pproduto, sldestoq, vpmsabado, vpmdomingo, rec.vprolotmul, rec.vproloteco, p_pmfloteco, p_pmcloteco, pmflotemu, pmclotemu);
		                                  
      	Perform fn_busca_infos_mrpii('E', deposito_array, p_mulemp, rec.pproduto, plano, rec.vpronome, rec.tpprodu, rec.propoli, rec.profanta, rec.pronivel, rec.pgrupo, rec.subgr,
                                   rec.punimed, sldnecess, qtdcompra, qtdreserv, qtdtmpcmp, qtdtmpres, sldfinal, '1', p_utilizaoc, rec.tmprepo, sldestoq, p_dataini, 
                                   p_datafim, sldminimo, qtdcompra);
	end loop;

	--MRPII08
	for rec2 in
		select 
			p.plnprodut as rec2plnprodut,
			p.plnsaldos as rec2plnsaldos
		from planee_tmp p   -- Sergio - OS 4185124 - 28/10/24
		where p.plncodigo = plano
	loop
		nececalen = 0;
	
		
	
		saldoini = rec2.rec2plnsaldos;
		saldoini := coalesce(saldoini,0);		
	
		for rec3 in
			select 
				p2.pln2neces as rec3pln2neces,
				p2.pln2sldre as rec3pln2sldre,
				p2.pln2sldin as rec3pln2sldin,
				p2.pln2sltex as rec3pln2sltex,
				p2.pln2dtper as rec3pln2dtper
			from planei_tmp p2  -- Sergio - OS 4185124 - 28/10/24
			where p2.pln2codig = plano and p2.pln2produ = rec2.rec2plnprodut
			order by p2.pln2codig, p2.pln2produ, p2.pln2dtper
		loop
			vrec2pln2neces = rec3.rec3pln2neces;
			vrec2pln2sldre = rec3.rec3pln2sldre;
			vrec2pln2sltex = rec3.rec3pln2sltex;		
			
			vrec2pln2neces := coalesce(vrec2pln2neces,0);
			vrec2pln2sldre := coalesce(vrec2pln2sldre,0);

			if (saldoini - vrec2pln2neces - vrec2pln2sldre) > 0 then
				saldoini = saldoini - vrec2pln2neces - vrec2pln2sldre;
			else
				saldoini = 0;
			end if;
			
		
			-- Sergio - OS 4185124 - 28/10/24
			update planei_tmp set pln2sldin = saldoini where pln2codig = plano and pln2produ = rec2.rec2plnprodut and pln2dtper = rec3.rec3pln2dtper ;
			
			vrec2pln2sltex := coalesce(vrec2pln2sltex,0);			
			nececalen = nececalen + vrec2pln2sltex;
		end loop;
		
		nececalen := coalesce(nececalen,0);	
		
		-- Sergio - OS 4185124 - 28/10/24
		update planee_tmp set plnslcale = nececalen where plncodigo = plano and plnprodut = rec2.rec2plnprodut;
	end loop;

--raise notice 'Vai inserir planece';
-- Sergio - OS 4185124 - 28/10/24
insert into planece 
select * from Planee_tmp;

--raise notice 'Vai inserir planecii';
insert into planecii 
select * from planei_tmp;

--raise notice 'Concluiu';

END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_inicio_mrpii(numeric, character, character, character, character, date, date, numeric, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, numeric, character, character, character, character, character, character, character, character, numeric, text, date, date, numeric, character, character) SET search_path=public, pg_temp;

ALTER FUNCTION fn_inicio_mrpii(numeric, character, character, character, character, date, date, numeric, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, character, numeric, character, character, character, character, character, character, character, character, numeric, text, date, date, numeric, character, character)
  OWNER TO postgres;
