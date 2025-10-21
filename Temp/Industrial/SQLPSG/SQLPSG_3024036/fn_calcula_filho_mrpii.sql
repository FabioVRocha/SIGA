-- Function: fn_calcula_filho_mrpii(numeric, character, numeric, numeric, date, character, character)

-- DROP FUNCTION fn_calcula_filho_mrpii(numeric, character, numeric, numeric, date, character, character);

CREATE OR REPLACE FUNCTION fn_calcula_filho_mrpii(pplano numeric, pproduto character, pquanti numeric, pqtdcmp numeric, pdtprevi date, psabado character, pdomingo character)
  RETURNS void AS
$BODY$
declare
	pfilho character(16);
	--qtdestrut numeric(15,4);
	qtdcompra numeric(15,4);
    qtdneces  numeric(15,4);
    qtdreserv numeric(15,4);
    qtdtmpcmp numeric(15,4);
    qtdtmpres numeric(15,4);
    vestqtduso numeric(15,4);
    qtdfinal numeric(15,4);
    dtreserva date;
    pronome character(50);
    fanta character(1);
   	origem character(1);
    tpreposi numeric(3);
    politica character(3);
    pronivel numeric(2);
    grupo numeric(3);
    subgrupo numeric(3);
    unimed character(2);
    dtprevi date;
    dtperiodo date;    
    dtfimperi date;
    dtteste date;
    vperiodo character(8);
    vdttemp date;   
    vnn integer;
    vnd integer;
    rec record;
    rec1 record;
    rec2 record;
   	vdelay numeric;
begin
	--select pldelay into vdelay from planos p where p.placodigo = pplano; --OS 4238225
	for rec in 
		select
			e.estfilho as pfilho,
			e.estqtduso * pquanti as qtdestrut,
			e.estqtduso as vestqtduso,
			p.pronome,
			p.profantasm as fanta,
			p.proorigem as origem,
			--p.protemrep + vdelay as ptmprepo, --OS 4238225, add a soma do vdelay
			p.protemrep as ptmprepo,
			p.proplest as politica,	
       		p.pronivelb as pronivel,
       		p.proarres,
       		p.proartol,
       		p.grupo,
       		p.subgrupo,
       		p.unimedida as unimed		
		from estrutur e 
		inner join produto p on p.produto = e.estfilho 
		where e.estproduto = pproduto
		order by estproduto, estfilho 		
	loop
		dtprevi = pdtprevi;
		--select 
		--	u.umprodt into dtprevi 
		--from umprodut u where u.umprodusu = 'SQLMRP' and u.umprodcod = pproduto;
		qtdcompra  = 0;
        qtdfinal   = 0;
        qtdreserv  = 0;
        qtdtmpcmp  = 0;
        qtdtmpres  = 0;
        qtdneces = rec.qtdestrut;
        -- mrpii15
        --dtteste = dtprevi;
       
		Select rec.ptmprepo ||' days' into vperiodo; 
		if (rec.origem = 'C' or (psabado = 'S' and pdomingo = 'S')) then
			dtprevi = dtprevi - (vperiodo::interval);		
		else
			if (pdomingo ='N' and psabado = 'N') then  -- sem final de semana
				vdttemp = dtprevi;	
				vnn = 1;
				while vnn <= rec.ptmprepo loop
					vdttemp = vdttemp - interval '1 day';
					select extract(DOW from vdttemp) into vnd;
					if vnd <> 0 and vnd <> 6 then 
						vnn = vnn +1;
					end if;
				end loop;
				dtprevi = vdttemp;
			else
				if pdomingo = 'N' then -- sem domingo
					vdttemp = dtprevi;	
					vnn = 1;
					while vnn <= rec.ptmprepo loop
						vdttemp = vdttemp - interval '1 day';
						select extract(DOW from vdttemp) into vnd;
						if vnd <> 0  then 
							vnn = vnn +1;
						end if;
					end loop;
					dtprevi = vdttemp;				
				else  
					if psabado = 'N' then -- sem s?bado
						vdttemp = dtprevi;	
						vnn = 1;
						while vnn <= rec.ptmprepo loop
							vdttemp = vdttemp - interval '1 day';
							select extract(DOW from vdttemp) into vnd;
							if vnd <> 6  then 
								vnn = vnn +1;
							end if;
						end loop;
						dtprevi = vdttemp;	
					end if;
				end if;
			end if;
		end if;	
	
		-- mrpii02 ok
		dtperiodo = null;
		dtfimperi = null;
		for rec1 in
		select permdtini as dtperiodo, permdtfim as dtfimperi from periplan p 
		where  permdtini <= pdtprevi and --Alterado de dtprevi para pdtprevi (original)
		       permdtfim >= pdtprevi	 --Alterado de dtprevi para pdtprevi (original)
		loop
			dtperiodo = rec1.dtperiodo;
			dtfimperi = rec1.dtfimperi;
		end loop;
	
		if dtperiodo is null or dtperiodo = '0001-01-01' then
			dtfimperi = current_date;
			dtperiodo = current_date;
		end if;
	
		if (rec.origem = 'C' or (psabado = 'S' and pdomingo = 'S')) then
			--Nao faz nada, mantendo a data que achou
		else
			if (pdomingo ='N' and psabado = 'N') then  -- sem final de semana
				vdttemp = dtperiodo;	
				select extract(DOW from vdttemp) into vnd;
				if vnd = 0 or vnd = 6 then 
					vnn = 1;
					while vnn <= 7 loop
						vdttemp = vdttemp - interval '1 day';
						select extract(DOW from vdttemp) into vnd;
						if vnd <> 0 and vnd <> 6 then 
							exit;
						end if;
						vnn = vnn + 1;
					end loop;
					dtperiodo = vdttemp;
				end if;
			else
				if pdomingo = 'N' then -- sem domingo
					select extract(DOW from vdttemp) into vnd;
					vdttemp = dtperiodo;	
					if vnd = 0 then 
						vnn = 1;
						while vnn <= 7 loop
							vdttemp = vdttemp - interval '1 day';
							select extract(DOW from vdttemp) into vnd;
							if vnd <> 0 then 
								exit;
							end if;
							vnn = vnn + 1;
						end loop;
						dtperiodo = vdttemp;	
					end if;
				else  
					if psabado = 'N' then -- sem sabado
						vdttemp = dtperiodo;	
						select extract(DOW from vdttemp) into vnd;
						if vnd = 6  then 
							vnn = 1;
							while vnn <= 7 loop
								vdttemp = vdttemp - interval '1 day';
								select extract(DOW from vdttemp) into vnd;
								if vnd <> 6  then 
									exit;
								end if;
								vnn = vnn + 1;
							end loop;
							dtperiodo = vdttemp;	
						end if;
					end if;
				end if;
			end if;
		end if;
		
	 	
	    --mrpii01 ok
		--if rec.pfilho = '09 K 100400' then
		--	raise notice '6Data: % ' , dtperiodo;
		--end if;
		perform fn_grava_necessidade_periodomrpii(pplano, rec.pfilho ,rec.pronome ,rec.origem,rec.politica,rec.fanta,rec.pronivel,
	    	rec.grupo,rec.subgrupo ,rec.unimed, qtdneces,qtdcompra,qtdreserv,qtdtmpcmp,qtdtmpres,qtdfinal,'1',dtperiodo, 
	      	0,rec.ptmprepo,0 );  
	
		dtreserva = dtperiodo - interval '1 day';
	
	    -- mrpii02 ok
		for rec2 in
		select permdtini as dtperiodo, permdtfim as dtfimperi from periplan p 
		where  permdtini <= dtreserva and 
		       permdtfim >= dtreserva
		loop
			dtperiodo = rec2.dtperiodo;
			dtfimperi = rec2.dtfimperi;
		end loop;
		if dtperiodo is null or dtperiodo = '0001-01-01' then
		   	dtfimperi = current_date;
			dtperiodo = current_date;
		end if;
	
		if (rec.origem = 'C' or (psabado = 'S' and pdomingo = 'S')) then
			--Nao faz nada, mantendo a data que achou
		else
			if (pdomingo ='N' and psabado = 'N') then  -- sem final de semana
				vdttemp = dtperiodo;	
				select extract(DOW from vdttemp) into vnd;
				if vnd = 0 or vnd = 6 then 
					vnn = 1;
					while vnn <= 7 loop
						vdttemp = vdttemp - interval '1 day';
						select extract(DOW from vdttemp) into vnd;
						if vnd <> 0 and vnd <> 6 then 
							exit;
						end if;
						vnn = vnn + 1;
					end loop;
					dtperiodo = vdttemp;
				end if;
			else
				if pdomingo = 'N' then -- sem domingo
					select extract(DOW from vdttemp) into vnd;
					vdttemp = dtperiodo;	
					if vnd = 0 then 
						vnn = 1;
						while vnn <= 7 loop
							vdttemp = vdttemp - interval '1 day';
							select extract(DOW from vdttemp) into vnd;
							if vnd <> 0 then 
								exit;
							end if;
							vnn = vnn + 1;
						end loop;
						dtperiodo = vdttemp;	
					end if;
				else  
					if psabado = 'N' then -- sem sabado
						vdttemp = dtperiodo;	
						select extract(DOW from vdttemp) into vnd;
						if vnd = 6  then 
							vnn = 1;
							while vnn <= 7 loop
								vdttemp = vdttemp - interval '1 day';
								select extract(DOW from vdttemp) into vnd;
								if vnd <> 6  then 
									exit;
								end if;
								vnn = vnn + 1;
							end loop;
							dtperiodo = vdttemp;	
						end if;
					end if;
				end if;
			end if;
		end if;
	
		qtdcompra  = 0;
        qtdneces   = 0;
        qtdreserv  = 0;
        qtdtmpcmp  = 0;
        qtdfinal   = 0;
        qtdtmpres  = pqtdcmp * rec.vestqtduso;
       	
	
       	--mrpii01 ok
       	--if rec.pfilho = '09 K 100400' then
		--	raise notice '7Data: % ' , dtperiodo;
		--end if;
		perform fn_grava_necessidade_periodomrpii(pplano, rec.pfilho ,rec.pronome ,rec.origem,rec.politica,rec.fanta,rec.pronivel,
	    	rec.grupo,rec.subgrupo ,rec.unimed, qtdneces,qtdcompra,qtdreserv,qtdtmpcmp,qtdtmpres,qtdfinal,'1',dtperiodo, 
	      	0,rec.ptmprepo,0 );
		
	end loop;
	
	
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_calcula_filho_mrpii(numeric, character, numeric, numeric, date, character, character) SET search_path=public, pg_temp;

ALTER FUNCTION fn_calcula_filho_mrpii(numeric, character, numeric, numeric, date, character, character)
  OWNER TO postgres;
