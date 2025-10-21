-- Function: fn_grava_necessidade_periodomrpii(numeric, character, character, character, character, character, numeric, numeric, numeric, character, numeric, numeric, numeric, numeric, numeric, numeric, character, date, numeric, numeric, numeric)

-- DROP FUNCTION fn_grava_necessidade_periodomrpii(numeric, character, character, character, character, character, numeric, numeric, numeric, character, numeric, numeric, numeric, numeric, numeric, numeric, character, date, numeric, numeric, numeric);

CREATE OR REPLACE FUNCTION fn_grava_necessidade_periodomrpii(pplano numeric, pproduto character, ppronome character, ptpprodu character, ppropoli character, pfanta character, pnivel numeric, pgrupo numeric, psubgr numeric, punimed character, psldnecess numeric, qtdcompra numeric, pqtdreserv numeric, pqtdtmpcmp numeric, pqtdtmpres numeric, pqtdfinal numeric, pdeonde character, pdtperiodo date, psldinicial numeric, ptmprepo numeric, psldpladisp numeric)
  RETURNS void AS
$BODY$
declare
	necepend numeric(15,4); 
	pdtperfim date;
    sld1 numeric(15,4);
    sld2 numeric(15,4);
    sld3 numeric(15,4);
    sld4 numeric(15,4);
    sld5 numeric(15,4);
    sld6 numeric(15,4);
    sldf numeric(15,4);
   	sld7 numeric(15,4);
   	vsldnecess numeric;
	vtdcompra numeric;
	vqtdreserv numeric;
	vsldpladisp numeric;
	vqtdtmpres numeric;
	sld8 numeric;
	planecii_pln2codig numeric;
	Valorx numeric;
	valory numeric;
begin
	--set datestyle = 'ISO, DMY';	
	--if pproduto = '09 K 100400' then
	--	raise notice 'Entrou data param %', pdtperiodo;
	--end if;
	
	select permdtfim  into pdtperfim from PERIPLAN where permdtini = pdtperiodo;
	vsldnecess = coalesce(psldnecess,0);
	vtdcompra = coalesce(qtdcompra,0);
	vqtdreserv = coalesce(pqtdreserv,0);
	vsldpladisp = coalesce(psldpladisp,0);
	vqtdtmpres = coalesce(pqtdtmpres,0);
	
    -- Sergio - OS 4185124 - 28/10/24
	--if exists (select 1 from planecii p where pln2codig = pplano and pln2dtper =  pdtperiodo and pln2produ = pproduto) then  
	select (PLN2SLEXD + PLN2SLDIN + PLN2SLDEX), PLN2SLDIN, PLN2SLEXD, PLN2SLTEX, PLN2TMPPR, PLN2SLDEX, (PLN2NECES + PLN2SLDRE), pln2codig   into sld1, sld4, sld5, sld6, sld7, sld8, sld2, planecii_pln2codig from planei_tmp p where pln2codig = pplano and pln2dtper =  pdtperiodo and pln2produ = pproduto;
			--select (PLN2NECES + PLN2SLDRE)  into sld2 from planecii p where pln2codig = pplano and pln2dtper =  pdtperiodo and pln2produ = pproduto	;
	if planecii_pln2codig is not null then
			
			if ptmprepo > 0 then
		   		sld7 = coalesce(ptmprepo,0);
		   	end if;
		   	
			sld4 := coalesce(sld4,0);
		
			--if sld4 <> 0 then
			if psldinicial <> 0 and psldinicial is not null then
				sld4 := coalesce(psldinicial,0);
			end if;
		
			sld4 := coalesce(sld4,0);	
		
			sld5 := coalesce(sld5,0) + coalesce(vtdcompra,0);
		
			sld1 = coalesce(sld5,0) + sld4 + coalesce(sld8,0);
			sld1 := coalesce(sld1,0);
			sld2 := coalesce(sld2,0);		

			if (sld1 < sld2) then     --(sld5 + sld4 + sld8) < (sld2) then
				sldf = coalesce(sld2,0) - coalesce(sld1,0);-- (sld5 + sld4 + sld8);
			else
				sldf = 0;
			end if;
		
			
		
			sldf := coalesce(sldf,0);
			pqtdtmpcmp := coalesce(pqtdtmpcmp,0);
			necepend = coalesce(pqtdtmpcmp,0);
				
			if sld4 > 0 then
				if necepend >= sld4 then
					necepend = coalesce(necepend,0) - coalesce(sld4,0);
					sld4 = 0;
				else
					sld4 = coalesce(sld4,0) - coalesce(necepend,0);
					necepend = 0;
				end if;					
			end if;
		
			if coalesce(sld5,0) > 0 then
				if coalesce(necepend,0) >= coalesce(sld5,0) then
					necepend = coalesce(necepend,0) - coalesce(sld5,0);
					sld5 = 0;
				  else
				  	sld5 = coalesce(sld5,0) - coalesce(necepend,0);
				    necepend = 0;
				end if;
			else
				sld6 := coalesce(sld6,0) + coalesce(pqtdtmpcmp,0);
			end if;
		
			update planei_tmp 
    		set 
    			PLN2TMPPR = sld7,
    			PLN2SLDIN = sld4, 
    			PLN2SLDFI = sldf,
    			PLN2NECES = PLN2NECES + vsldnecess,  -- pqtdfinal
    			PLN2SLDEX = PLN2SLDEX + vtdcompra,
    			PLN2SLDRE = PLN2SLDRE + vqtdreserv,
    			PLN2PLADI = PLN2PLADI + vsldpladisp, 
    			PLN2SLEXD = sld5, 
    			PLN2SLTEX = sld6, --+ pqtdtmpcmp, 
    			PLN2SLTRE = PLN2SLTRE + vqtdtmpres 
    		where pln2codig = pplano and pln2dtper = pdtperiodo and pln2produ = pproduto;     		
    	else    
    	
    		--if pproduto = '09 K 100400' then
			--	raise notice 'INS data param %', pdtperiodo;
			--end if;
    	
    	
    		-- Sergio - OS 4185124 - 28/10/24
			INSERT INTO planei_tmp
			(PLN2CODIG,PLN2DTPER,PLN2PRODU,PLN2PRODE,PLN2PROTI,PLN2POLIT,PLN2FANTA,PLN2PRONI,PLN2GRUPO,PLN2SUBGR,PLN2UNIME,PLN2NECES,  --12
			 PLN2SLDEX,PLN2SLDRE,PLN2SLTEX,PLN2SLTRE,PLN2SLDFI,PLN2NEORI,PLN2PLADI,PLN2ESALT,PLN2CONFI,PLN2SLDIN,PLN2SLEXD,PLN2TMPPR,PLN2DTFIM)
			 Values(pplano, pdtperiodo, pproduto, ppronome, ptpprodu, ppropoli, pfanta, pnivel, pgrupo, psubgr, punimed, vsldnecess,
			 vtdcompra, vqtdreserv, pqtdtmpcmp, vqtdtmpres, pqtdfinal, pqtdfinal, vsldpladisp , 'Z', pdeonde, 0, vtdcompra, ptmprepo , pdtperfim ) ;
		end if; 
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_grava_necessidade_periodomrpii(numeric, character, character, character, character, character, numeric, numeric, numeric, character, numeric, numeric, numeric, numeric, numeric, numeric, character, date, numeric, numeric, numeric) SET search_path=public, pg_temp;

ALTER FUNCTION fn_grava_necessidade_periodomrpii(numeric, character, character, character, character, character, numeric, numeric, numeric, character, numeric, numeric, numeric, numeric, numeric, numeric, character, date, numeric, numeric, numeric)
  OWNER TO postgres;
