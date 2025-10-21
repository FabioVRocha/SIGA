-- Function: fn_processa_necessidades_periodomrpii(numeric, character, numeric, character, character, numeric, numeric, character, character, character, character)

-- DROP FUNCTION fn_processa_necessidades_periodomrpii(numeric, character, numeric, character, character, numeric, numeric, character, character, character, character);

CREATE OR REPLACE FUNCTION fn_processa_necessidades_periodomrpii(pplano numeric, pproduto character, psldinicial numeric, psabado character, pdomingo character, pprolotmul numeric, pproloteco numeric, ppmfloteco character, ppmcloteco character, ppmflotemu character, ppmclotemu character)
  RETURNS void AS
$BODY$
declare
    slddisponi numeric(15,4); 
	orddispon numeric(15,4);
	qtddif numeric(15,4);
    qtdmem numeric(15,4);
    vz numeric(15,4);
    pdata date;
    pronome character(50);
    fanta character(1);
   	origem character(1);
    --tpreposi numeric(3);
    politica character(3);
    pronivel numeric(2);
    grupo numeric(3);
    subgrupo numeric(3);
    unimed character(2);
   	qtdcompra numeric(15,4);
    qtdneces numeric(15,4);
    qtdreserv numeric(15,4);
    qtdtmpcmp numeric(15,4);
    qtdtmpres numeric(15,4);
    pdtprevi date;
    qtdfinal numeric(15,4);
   	qtdfilho numeric(15,4);  
   	--pln2sldre numeric(15,4);
    multipli numeric(15,4);
    necepend numeric(15,4);
    sldpladis numeric(15,4);
    dtperiodo date;
    dtfimperi date;	
	vperiodo character(8);
	vnn integer;
	vnd integer;
	vdttemp date;
    rec record;
   	rec2 record;
   	vptmprepo numeric;
    gravar numeric;
    valorX numeric;
    valory numeric;
    n1 numeric;
    n2 numeric;
    n3 numeric;
    dt date;
    texto text;
    vdelay numeric;
begin
	orddispon = 0;
	slddisponi = psldinicial;
	qtddif = 0;
	qtdmem = 0;
	multipli = 0;
	vz = 1;
	--select pldelay into vdelay from planos p where p.placodigo = pplano; --OS 4238225
	for rec in
		select 
			i.PLN2DTPER as pdata,
			i.PLN2SLEXD as orddispon,
			0 as qtdcompra,
			0 as qtdneces,
			0 as qtdreserv,
			0 as qtdtmpcmp,
			0 as qtdtmpres,
			i.PLN2DTPER as pdtprevi,
			i.PLN2SLDRE as vpln2sldre,
			i.PLN2NECES as pln2neces,
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
       		--pplan.permdtini as dtperiodo,
       		--pplan.permdtfim as dtfimperi
		from planei_tmp i
		inner join PRODUTO p on p.PRODUTO = i.PLN2PRODU
		--left join periplan pplan ON pplan.permdtfim >= i.PLN2DTPER AND pplan.permdtini <= i.PLN2DTPER
		where i.PLN2CODIG = pplano and 
		      i.PLN2PRODU = pproduto and 
		      i.PLN2CONFI = '1'	
	      order by i.pln2codig, i.pln2produ, i.pln2dtper 
	loop
		qtdcompra = 0;
		qtdneces  = 0;
		qtdreserv = 0;
		qtdtmpcmp = 0;
		qtdtmpres = 0;
		vptmprepo = rec.ptmprepo;
		if vptmprepo is null then
			vptmprepo = 0;
		end if;
		dt = rec.pdtprevi;
		pdtprevi = rec.pdtprevi;
			
		--if rec.orddispon is null then
			--orddispon = orddispon;
		--else
			orddispon = coalesce(orddispon,0) + coalesce(rec.orddispon,0);
		--end if;
	       
		qtdfinal = coalesce(rec.pln2neces,0) - ( coalesce(slddisponi,0) + coalesce(orddispon,0) - coalesce(rec.vpln2sldre,0) );		
		qtdfilho = coalesce(rec.pln2neces,0) - ( coalesce(slddisponi,0) + coalesce(orddispon,0) - coalesce(rec.vpln2sldre,0) );
		
		if qtdfinal > 0 then
			if qtddif > qtdfinal then
				qtdfinal = 0;
			   else
			    qtdfinal = coalesce(qtdfinal,0) - coalesce(qtddif,0);
		    end if;
			qtdmem = qtdfinal;
			if qtdfinal > 0 then
				if ((rec.origem = 'F' and ppmfloteco = 'S') or (rec.origem = 'C' and ppmcloteco = 'S')) and pproloteco > 0 then 
					if qtdfinal < pproloteco then
						qtdfinal = coalesce(pproloteco,0);
						qtdfilho = coalesce(qtdfinal,0);
					end if;
				end if;
				if ((rec.origem = 'F' and ppmflotemu = 'S') or (rec.origem = 'C' and ppmclotemu = 'S')) and pprolotmul > 0 then  
					if qtdfinal < pprolotmul then	
						qtdfinal = coalesce(pprolotmul,0);
						qtdfilho = coalesce(qtdfinal,0);
					  else
					  	multipli = ( coalesce(qtdfinal,0) / coalesce(pprolotmul,0) ) + 0.99; --* 0.99;
					  	multipli = trunc(coalesce(multipli,0));
						qtdfinal = coalesce(pprolotmul,0) * coalesce(multipli,0);
						qtdfilho = coalesce(qtdfinal,0);
					end if;
				end if;
			end if;		
		end if;
		necepend = coalesce(rec.pln2neces,0) + coalesce(rec.vpln2sldre,0);
		
		if coalesce(necepend,0) >= coalesce(slddisponi,0) then
			necepend = coalesce(necepend,0) - coalesce(slddisponi,0);
			slddisponi = 0;
		  else
		  	slddisponi = coalesce(slddisponi,0) - coalesce(necepend,0);
		  	necepend = 0;
		end if;
		
		if necepend >= orddispon then
			necepend = coalesce(necepend,0) - coalesce(orddispon,0);
			orddispon = 0;
		  else		
			orddispon = coalesce(orddispon,0) - coalesce(necepend,0);
			necepend = 0;	
		end if;
		
		--if coalesce(qtdfinal,0) <= 0 then
		if coalesce(qtdfinal,0) < 0 then
			qtdtmpcmp = 0;
			sldpladis = 0;
		  else
		  	sldpladis = coalesce(qtdfinal,0);
		end if;
		if rec.origem = 'F' then
			if rec.proarres	 = 'S' then
				if mod(qtdfinal,1)<> 0 then
					if qtdfinal < 1 then
						qtdfinal = 1;
					  else
						if qtdfinal > (truncate(qtdfinal,0)+coalesce(rec.proartol,0) ) then
							qtdfinal = coalesce(qtdfinal,0) + 1;
						end if;
						qtdfinal = truncate(qtdfinal,0);
					end if;					
				end if;		
			end if;
		end if;	
	
		--if pproduto = '09 K 100400' then
		--	raise notice '1Data: % ' , pdtprevi;
		--end if;
				
		-- mrpii01 oK
		perform fn_grava_necessidade_periodomrpii(pplano, pproduto ,rec.pronome ,rec.origem,rec.politica,rec.fanta,rec.pronivel,
	    	rec.grupo,rec.subgrupo ,rec.unimed, 0, 0, 0, 0, 0,qtdfinal,'2',pdtprevi, 0,
	      	vptmprepo,sldpladis );
	
		if qtdfinal < 0 then
			qtdfinal = 0;
		end if;
		if qtdfinal > qtdmem then
			qtddif = coalesce(qtdfinal,0) - coalesce(qtdmem,0);
		  else
		  	qtddif = 0;
		end if;
	
		-- mrpii15 ok
	
		if (vptmprepo <= 1) then
			Select vptmprepo || ' day' into vperiodo; 
		else
			Select vptmprepo || ' days' into vperiodo; 
		end if;
	     
		
		if (rec.origem = 'C' or (psabado = 'S' and pdomingo = 'S')) then
			pdtprevi = rec.pdtprevi - (vperiodo::interval);		
		else
			if (pdomingo ='N' and psabado = 'N') then  -- sem final de semana
				vdttemp = rec.pdtprevi;	
				vnn = 1;
				while vnn <= vptmprepo loop
					vdttemp = vdttemp - interval '1 day';
					select extract(DOW from vdttemp) into vnd;
					if vnd <> 0 and vnd <> 6 then 
						vnn = vnn +1;
					end if;
				end loop;
				pdtprevi = vdttemp;
			else
				if pdomingo = 'N' then -- sem domingo
					vdttemp = rec.pdtprevi;	
					vnn = 1;
					while vnn <= vptmprepo loop
						vdttemp = rec.pdtprevi - interval '1 day';
						select extract(DOW from vdttemp) into vnd;
						if vnd <> 0  then 
							vnn = vnn +1;
						end if;
					end loop;
					pdtprevi = vdttemp;				
				else  
					if psabado = 'N' then -- sem sabado
						vdttemp = rec.pdtprevi;	
						vnn = 1;
						while vnn <= vptmprepo loop
							vdttemp = vdttemp - interval '1 day';
							select extract(DOW from vdttemp) into vnd;
							if vnd <> 6  then 
								vnn = vnn +1;
							end if;
						end loop;
						pdtprevi = vdttemp;	
					end if;
				end if;
			end if;
		end if;	
	
		pdtprevi = pdtprevi - interval '1 day';
	
		-- mrpii02 ok
		dtperiodo = null;
		dtfimperi = null;
		for rec2 in
		select permdtini as dtperiodo, permdtfim as dtfimperi from periplan p 
		where  permdtini <= pdtprevi and 
		       permdtfim >= pdtprevi
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
	
		--if pproduto = '09 K 100400' then
		--	raise notice '2Data: % ' , dtperiodo;
		--end if;
		qtdtmpcmp = coalesce(qtdfinal,0);
		qtdfinal = 0;
		
		-- mrpii01 ok
		perform fn_grava_necessidade_periodomrpii(pplano, pproduto ,rec.pronome ,rec.origem,rec.politica,rec.fanta,rec.pronivel,
	    	rec.grupo,rec.subgrupo ,rec.unimed, 0, 0, 0, qtdtmpcmp, 0,qtdfinal,'2',dtperiodo, 0,
	      	vptmprepo, 0 );	
	
	      
	      -- mrpii09 ok
      	update planei_tmp --  planecii  Sergio - OS 4185124 - 28/10/24 
		set PLN2SLEXD = coalesce(orddispon,0), 
		    PLN2SLDIN = coalesce(slddisponi,0)
		where PLN2CODIG = pplano and 
		      PLN2PRODU = pproduto and 
			  PLN2DTPER = rec.pdata;
			 
		--perform fn_acerto_saldos_disp_periodomrpii(pplano, pproduto, rec.pdata, slddisponi, orddispon); 
	
		--delete from umprodut where umprodusu = 'SQLMRP';
		--insert into umprodut (umprodusu, umprodcod, umprodt) values ('SQLMRP', pproduto, dtperiodo);
		if upper(rec.origem)::text = upper('F')::text and (coalesce(qtdfilho,0) > 0 or coalesce(qtdtmpcmp,0) > 0) then
			-- mrpii07 ok
			perform fn_calcula_filho_mrpii(pplano, pproduto, qtdfilho, qtdtmpcmp, dtperiodo, psabado, pdomingo);
		end if;

	end loop;
end;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_processa_necessidades_periodomrpii(numeric, character, numeric, character, character, numeric, numeric, character, character, character, character) SET search_path=public, pg_temp;

ALTER FUNCTION fn_processa_necessidades_periodomrpii(numeric, character, numeric, character, character, numeric, numeric, character, character, character, character)
  OWNER TO postgres;
