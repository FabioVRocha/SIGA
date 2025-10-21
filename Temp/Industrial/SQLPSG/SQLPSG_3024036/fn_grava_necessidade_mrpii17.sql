-- Function: fn_grava_necessidade_mrpii17(numeric, character, character, character, numeric, numeric, numeric, numeric, numeric, numeric, character, character, character, character, numeric, numeric, numeric)

-- DROP FUNCTION fn_grava_necessidade_mrpii17(numeric, character, character, character, numeric, numeric, numeric, numeric, numeric, numeric, character, character, character, character, numeric, numeric, numeric);

CREATE OR REPLACE FUNCTION fn_grava_necessidade_mrpii17(pplano numeric, pproduto character, ptpprodu character, punimed character, psldnecess numeric, psaldos numeric, psldmin numeric, qtdcompra numeric, pqtdfinal numeric, pqtdreserv numeric, pdeonde character, ppronome character, ppropoli character, pfanta character, pnivel numeric, pgrupo numeric, psubgr numeric)
  RETURNS void AS
$BODY$
declare
	--necepend numeric(15,4);  
	--pdtperfim date;
    retorno numeric(1); 
    sld1 numeric(15,4);
    sld2 numeric(15,4);
    sld3 numeric(15,4);
    sld4 numeric(15,4);
    sld5 numeric(15,4);
   	sld6 numeric(15,4);
    sld7 numeric(15,4);
    sld8 character(6);
    sld9 character(1);
    sld10 numeric(15,4);
    sld11 numeric(15,4);
    sldf numeric(15,4);
    contador numeric(3);
    plano_codigo numeric;
begin
	--set datestyle = 'ISO, DMY';	
	if (pfanta <> 'S' and pfanta <> 'M') then
		pfanta = 'N' ;
	end if;
	contador = 0;
    retorno = 0;
   	if pqtdfinal < 0 then
    	pqtdfinal = 0;
    end if;
   
   	--if exists (select 1 from planece p where plncodigo = pplano and plnprodut = pproduto) then
	select PLNSLDFIM, PLNSALDOS, PLNSLDDIS,PLNSLDEXT, PLNSLEXDI, PLNSLDRES, PLNSLMINI, PLNPOLITI, PLNFANTAS, PLNPRONIV, PLNNECESS, PLNCODIGO 
	into sld1, sld2, sld3, sld4, sld5, sld6, sld7, sld8, sld9, sld10, sld11, plano_codigo 
	from planee_tmp p   -- S?rgio - OS 4185124 - 28/10/24
	where plncodigo = pplano and plnprodut = pproduto;
	if plano_codigo is not null then
		   	sld1 := coalesce(sld1, 0);			
			pqtdfinal := coalesce(pqtdfinal,0);
			
		   	pqtdfinal = sld1 + pqtdfinal;
			if pqtdfinal < 0 then
				pqtdfinal := 0;
			end if;
			psaldos := coalesce(psaldos,0);			
			if psaldos <> 0 then
				sld2 := psaldos;
				sld3 := psaldos;			
			end if;
			qtdcompra := coalesce(qtdcompra,0);			
			if qtdcompra <> 0 then
				if sld4 is null then
					sld4 := 0;
				end if;
				if sld5 is null then
					sld5 := 0;
				end if;
				sld4 := sld4 + qtdcompra;
				sld5 := sld5 + qtdcompra;
			end if;
			pqtdreserv := coalesce(pqtdreserv,0);					
			if pqtdreserv <> 0 then				
				sld6 := pqtdreserv;
			end if;
			psldmin := coalesce(psldmin,0);
			if psldmin <> 0 then
				sld7 := psldmin;
			end if;		
			if length(trim(ppropoli)) <> 0 then
				sld8 := ppropoli;
			end if;		
			if length(trim(pfanta)) <> 0 then
				if pfanta = 'M' then
					sld9 := pfanta;
				end if;
			end if;		
			if pnivel > 0 then
				sld10 := pnivel;
			end if;	
			sld11 := coalesce(sld11,0);
			psldnecess := coalesce(psldnecess,0);			

			sld11 := sld11 + psldnecess ;
			
			--if pproduto = '0667' then
			--	raise notice 'No 17 ba -->> % ;(%); [%] ; [%] ; [%]; (<%>) ; <%> ',pproduto ,sld11, psldnecess ,sld7, sld6, sld2, sld5 ;
			--end if;
		
			update planee_tmp   -- Sergio - Os 4185124 - 28/10/24
    		set PLNNECESS = sld11, 
    			PLNSALDOS = sld2,
    			PLNSLDDIS = sld3,
    			PLNSLDEXT = sld4,
    			PLNSLEXDI = sld5,
    			PLNSLDRES = sld6, 
    			PLNSLMINI = sld7, 
    			PLNPRODES = ppronome, 
    			PLNUNIMED = punimed, 
    			PLNPROTIP = ptpprodu,
    			PLNRNECOR = pqtdfinal,
    			PLNPOLITI = sld8, 
    			PLNFANTAS = sld9, 
    			PLNPRONIV = sld10,
    			PLNSLDFIM = pqtdfinal
    		where plncodigo = pplano and plnprodut = pproduto;
    		
    		retorno = 1;
    	else 
    		--if pproduto = 'MP00043'then
			--	raise notice 'No 17 ab -->> % ;(%); [%] ; [%] ; [%]; (<%>) ; <%> ',pproduto ,sld11, psldnecess ,sld7, sld6, sld2, sld5 ;
			--end if;
    		
			INSERT INTO planee_tmp
			(PLNCODIGO,PLNPRODUT,PLNPROTIP,PLNUNIMED,PLNNECESS,PLNSALDOS,PLNSLMINI,PLNSLDEXT,PLNSLDFIM,PLNSLDRES,PLNCONFIR,
			 PLNPRODES,	PLNPOLITI, PLNFANTAS, PLNPRONIV, PLNRNECOR, PLNESALTE, PLNPGRUPO, PLNPSUBGR, PLNSLDDIS, PLNSLEXDI)   
			 Values(pplano, pproduto, ptpprodu, punimed, psldnecess, psaldos, psldmin, qtdcompra, pqtdfinal,pqtdreserv, pdeonde,
			 ppronome, ppropoli, pfanta, pnivel, pqtdfinal, 'Z', pgrupo, psubgr, psaldos, qtdcompra ) ;
			
			retorno = 0;
	end if; 
	
	--return retorno;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_grava_necessidade_mrpii17(numeric, character, character, character, numeric, numeric, numeric, numeric, numeric, numeric, character, character, character, character, numeric, numeric, numeric) SET search_path=public, pg_temp;

ALTER FUNCTION fn_grava_necessidade_mrpii17(numeric, character, character, character, numeric, numeric, numeric, numeric, numeric, numeric, character, character, character, character, numeric, numeric, numeric)
  OWNER TO postgres;
