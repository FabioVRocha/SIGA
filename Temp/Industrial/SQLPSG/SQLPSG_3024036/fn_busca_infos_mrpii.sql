-- Function: fn_busca_infos_mrpii(character, integer[], character, character, numeric, character, character, character, character, numeric, numeric, numeric, character, numeric, numeric, numeric, numeric, numeric, numeric, character, character, numeric, numeric, date, date, numeric, numeric)

-- DROP FUNCTION fn_busca_infos_mrpii(character, integer[], character, character, numeric, character, character, character, character, numeric, numeric, numeric, character, numeric, numeric, numeric, numeric, numeric, numeric, character, character, numeric, numeric, date, date, numeric, numeric);

CREATE OR REPLACE FUNCTION fn_busca_infos_mrpii(ptipodebusca character, pdeposito integer[], pmultiempresa character, pproduto character, pplano numeric, ppronome character, ptpprodu character, ppropoli character, pfanta character, pnivel numeric, pgrupo numeric, psubgr numeric, punimed character, pqtdnecess numeric, qtdcompra numeric, pqtdreserv numeric, pqtdtmpcmp numeric, pqtdtmpres numeric, pqtdfinal numeric, pnumero character, utilizaoc character, ptmprepo numeric, psldinicial numeric, pdataini date, pdatafim date, psldmin numeric, acumulado numeric)
  RETURNS numeric AS
$BODY$
DECLARE
    deposito_array int[];
    --qtdcompra numeric(15,4);
    sldcompra numeric(15,4);
    dataini date;
    datafim date;
    dtperiodo date; 
    filho character(16);
	pSldnecess numeric(15,4);
	pSldnecess1 numeric(15,4);
	vproplest character(5);
	grupo numeric(3);
	subgrupo numeric(3);
	fanta character(1);
	origem character(1);
	estfanta character(1);
	reqord numeric(7);
	sldreq numeric(15,4);
	fase numeric(2);
	status character(1);
    pdeonde character(1);
    psldpladisp numeric(15,4);
    nomefilho character(50);
   	polfilho character(6);
    vqtduso numeric(15,4);
    vminimo numeric(15,4);
    retorno numeric(15,4);
    rec record;
   	vpermdtini date;
    grava numeric;
begin
    
    deposito_array = pdeposito;
	pdeonde = pnumero;
    psldpladisp = 0;
	retorno = 0;		
   IF ptipodebusca = 'O' then
    	-- Ordens
    	for rec in
    	SELECT 
    	    pplano as PLN2CODIG,
    		pplan.permdtfim as PLN2DTPER ,
    		pproduto as PLN2PRODU,
    		ppronome as PLN2PRODE,
    		ptpprodu as PLN2PROTI,
    		ppropoli as PLN2POLIT,
    		pfanta as PLN2FANTA,
    		pnivel as PLN2PRONI,
    		pgrupo as PLN2GRUPO,
    		psubgr as PLN2SUBGR,
    		punimed as PLN2UNIME, 
    		psldnecess as PLN2NECES,   --(o.ordquanti + COALESCE(SUM(t.priquanti), 0) - COALESCE(SUM(p.perqtdper), 0)) as psldnecess,    			    	
            (o.ordquanti - COALESCE(SUM(t.priquanti), 0) - COALESCE(SUM(p.perqtdper), 0)) AS PLN2SLDEX,  -- pln2sldex           
            pqtdreserv as PLN2SLDRE, -- (o.ordquanti + COALESCE(SUM(t.priquanti), 0) - COALESCE(SUM(p.perqtdper), 0)) AS sldcompra,  -- pln2sldre
            pqtdtmpcmp as PLN2SLTEX, -- pln2sltex
            0 as PLN2SLTRE, --psldmin as PLN2SLTRE,
            pqtdfinal as PLN2SLDFI ,
            pqtdfinal as PLN2NEORI,
            psldpladisp as PLN2PLADI,
            'Z' as PLN2ESALT,
            pdeonde as PLN2CONFI,             
            psldinicial as PLN2SLDIN,
            (o.ordquanti - COALESCE(SUM(t.priquanti), 0) - COALESCE(SUM(p.perqtdper), 0)) AS PLN2SLEXD,
            ptmprepo as PLN2TMPPR,            
            pplan.permdtfim  as PLN2DTFIM        
        FROM ordem o
        Left JOIN toqmovi t ON t.priordem = o.ordem AND t.priproduto = o.ordproduto
        left JOIN perdas p ON p.perofscod = o.ordem
        left JOIN periplan pplan ON pplan.permdtfim >= o.orddtprev AND pplan.permdtini <= o.orddtprev
        WHERE o.ordproduto = pproduto
            AND (o.orddtence IS NULL OR o.orddtence = '0001-01-01')
            AND (o.orddtprev <= pdatafim AND (o.orddrpmrp IS NULL OR o.orddrpmrp = '0001-01-01') OR (o.orddrpmrp <= pdatafim AND o.orddrpmrp <> '0001-01-01'))
            AND ( deposito_array = '{}'::int[]   OR  o.orddeposit = ANY(deposito_array))
            
        	group by  pplan.permdtfim,o.ordem , o.ordquanti
            order by  o.orddtence desc --pplan.permdtfim    
        
       		
       	loop
	       	
       		
	       	if (rec.PLN2DTPER is null or rec.PLN2DTPER = '0001-01-01') then
       			datafim := CURRENT_DATE + interval '1 day';
       		  else
       		    datafim := rec.PLN2DTPER + interval '1 day';
	       	end if;
        	
        	
        	dtperiodo = datafim;

            retorno = retorno + rec.PLN2SLDEX;
           		
	           	--if rec.PLN2PRODU = '09 K 100400' then
				--	raise notice '3Data: % ' , dtperiodo;
				--end if;
	       		perform fn_grava_necessidade_periodomrpii(rec.PLN2CODIG, rec.PLN2PRODU,rec.PLN2PRODE,rec.PLN2PROTI,rec.PLN2POLIT,rec.PLN2FANTA,rec.PLN2PRONI,
	       		rec.PLN2GRUPO,rec.PLN2SUBGR,rec.PLN2UNIME, 0,rec.PLN2SLDEX, 0, 0, 0, 0,rec.PLN2CONFI,dtperiodo,
	       		0, 0, 0 );
	       	    --rec.PLN2SLDIN,rec.PLN2TMPPR,rec.PLN2PLADI );
			       		
       	end loop;        		
	     
        
    END IF;
   
    IF ptipodebusca = 'C' then
    	-- Compras
    	
   		for rec in
    	SELECT 
    		pplano as PLN2CODIG,
    		pplan.permdtfim as PLN2DTPER ,
    		pproduto as PLN2PRODU,
    		ppronome as PLN2PRODE,
    		ptpprodu as PLN2PROTI,
    		ppropoli as PLN2POLIT,
    		pfanta as PLN2FANTA,
    		pnivel as PLN2PRONI,
    		pgrupo as PLN2GRUPO,
    		psubgr as PLN2SUBGR,
    		punimed as PLN2UNIME,            
            psldnecess as PLN2NECES,  --r.rqcsaldo as     			    	
            r.rqcsaldo AS PLN2SLDEX,
            pqtdreserv as PLN2SLDRE,  
            pqtdtmpcmp as PLN2SLTEX,  -- pln2sltex     --sldcompra + r.rqcsaldo AS sldcompra,
            pqtdtmpres as PLN2SLTRE,
            pqtdfinal as PLN2SLDFI,
            pqtdfinal as PLN2NEORI,
            psldpladisp as PLN2PLADI,
            'Z' as PLN2ESALT,
            pdeonde as PLN2CONFI,             
            psldinicial as PLN2SLDIN,
            r.rqcsaldo as PLN2SLEXD,
            ptmprepo as PLN2TMPPR,            
            pplan.permdtfim as PLN2DTFIM        
        FROM reqcomp r        
        LEFT JOIN periplan pplan ON pplan.permdtfim >= r.rqcprevi  AND pplan.permdtini <= r.rqcprevi
        WHERE r.produto  = pproduto
            AND (r.rqcdtate is null or r.rqcdtate = '0001-01-01' )
            AND r.rqcprevi  <= pdatafim 
            AND (deposito_array = '{}'::int[]    OR     r.rqcdepos = ANY(deposito_array))
            AND (utilizaoc <> 'S' OR r.rqcstatus = 'L')
        --group by  r.rqcprevi, pplan.permdtfim, r.rqcsaldo 
        ORDER by r.rqcprevi --pplan.permdtini ;
       
       	
       	loop	
       		if rec.PLN2DTPER is null or rec.PLN2DTPER = '0001-01-01' then
       			datafim = CURRENT_DATE + interval '1 day';
       		  else
       		    datafim = rec.PLN2DTPER + interval '1 day';
	       	end if;
 	        
       	   
 	       	select 
 	       		p.permdtini 
 	       		into
 	       		vpermdtini
 	        from periplan p where p.permdtfim >= datafim and p.permdtini <= datafim;
 	       
 	        vpermdtini := coalesce(vpermdtini,CURRENT_DATE);	
 	       
 	       
 	       	dtperiodo = vpermdtini;
       		
       		retorno = retorno + rec.PLN2SLDEX;
       		--if rec.PLN2PRODU = '09 K 100400' then
			--	raise notice '4Data: % ' , dtperiodo;
			--end if;
   			perform fn_grava_necessidade_periodomrpii(rec.PLN2CODIG, rec.PLN2PRODU,rec.PLN2PRODE,rec.PLN2PROTI,rec.PLN2POLIT,rec.PLN2FANTA,rec.PLN2PRONI,
       		rec.PLN2GRUPO,rec.PLN2SUBGR,rec.PLN2UNIME, 0,rec.PLN2SLDEX, 0, 0, 0, 0,rec.PLN2CONFI,dtperiodo,
       		0, 0, 0 );
       	    --rec.PLN2SLDIN,rec.PLN2TMPPR,rec.PLN2PLADI );
		end Loop; 
	
   		
    end if;
    
    IF ptipodebusca = 'R' then
    	-- Reservas
    	
			--PLN2CODIG,PLN2DTPER,PLN2PRODU,PLN2PRODE,PLN2PROTI,PLN2POLIT,PLN2FANTA,PLN2PRONI,PLN2GRUPO,PLN2SUBGR,PLN2UNIME,PLN2NECES,
			--PLN2SLDEX,PLN2SLDRE,PLN2SLTEX,PLN2SLTRE,PLN2SLDFI,PLN2NEORI,PLN2PLADI,PLN2ESALT,PLN2CONFI,PLN2SLDIN,PLN2SLEXD,PLN2TMPPR,PLN2DTFIM)
    	for rec in
    	SELECT 
    		pplano as PLN2CODIG,
    		pplan.permdtini as PLN2DTPER ,
    		pproduto as PLN2PRODU,
    		ppronome as PLN2PRODE,
    		ptpprodu as PLN2PROTI,
    		ppropoli as PLN2POLIT,
    		pfanta as PLN2FANTA,
    		pnivel as PLN2PRONI,
    		pgrupo as PLN2GRUPO,
    		psubgr as PLN2SUBGR,
    		punimed as PLN2UNIME,
    		0 as PLN2NECES,    			    	
            (select fn_saldo_produto_reservado( R2.reqord, pproduto )) As sldreq,
            0 as PLN2SLDEX,  -- PLN2SLDEX
            r2.rqoquanti + (select fn_saldo_produto_reservado( R2.reqord, pproduto )) as PLN2SLDRE, --0, OS 4185124
    		0  as PLN2SLTEX, --r2.rqoquanti as sldreq,-- PLN2SLTEX                          
            pqtdtmpres as PLN2SLTRE,
            pqtdfinal as PLN2SLDFI,
            pqtdfinal as PLN2NEORI,
            psldpladisp as PLN2PLADI,
            'Z' as PLN2ESALT,
            pdeonde as PLN2CONFI,               
            psldinicial as PLN2SLDIN,
            0 as PLN2SLEXD,
            ptmprepo PLN2TMPPR,            
            pplan.permdtfim as PLN2DTFIM       
        FROM reqordem r2 
        inner join ordem o on o.ordem  = R2.reqord 
        LEFT JOIN periplan pplan ON pplan.permdtfim >= o.orddtaber  AND pplan.permdtini <= o.orddtaber
        WHERE r2.reqproduto  = pproduto 
            and (o.orddtence is null or o.orddtence = '0001-01-01')
        	AND o.orddtprev <= pdatafim 
            AND (deposito_array = '{}'::int[]    OR  o.orddeposit = ANY(deposito_array))
            AND (r2.reqdepo = o.orddeposit) 
        order by o.orddtaber        
    
 
       	loop	
			
	       	if rec.PLN2DTPER is null or rec.PLN2DTPER = '0001-01-01' then
				datafim = current_date;
			else			
	       		datafim = rec.PLN2DTPER; --  + interval '1 day';
	       	end if;
	       
	        dtperiodo = datafim; 
	        pqtdreserv = 0;
	       
       		if rec.PLN2SLDRE > 0 then
   	    		pqtdtmpres = pqtdtmpres + rec.PLN2SLDRE;
   				pqtdreserv = rec.PLN2SLDRE; 
   				retorno = retorno + rec.PLN2SLDRE;
   				--if rec.PLN2PRODU = '09 K 100400' then
				--	raise notice '5Data: % ' , dtperiodo;
				--end if;
				Perform fn_grava_necessidade_periodomrpii(rec.PLN2CODIG, rec.PLN2PRODU,rec.PLN2PRODE,rec.PLN2PROTI,rec.PLN2POLIT,rec.PLN2FANTA,rec.PLN2PRONI,
   				rec.PLN2GRUPO,rec.PLN2SUBGR,rec.PLN2UNIME, 0,rec.PLN2SLDEX,rec.PLN2SLDRE, 0, 0, 0,rec.PLN2CONFI,dtperiodo,
   				0, 0, 0 );
   	    		--rec.PLN2SLDIN,rec.PLN2TMPPR,rec.PLN2PLADI );
       	   	end if;
    	end loop;
    	
   	end if;
    
   	IF ptipodebusca = 'E' then
   		-- Estrutura
   		
   	    qtdcompra = 0;
   	    pSldnecess1 =0;
   		for rec in
   			select 	   			
   			e.estfilho as filho,
   			e.estqtduso as pSldnecess,
   			p.proplest as vproplest,
   			p.grupo as grupo,
   			p.subgrupo as subgrupo,
   			p.profantasm as fanta,
   			p.proorigem as origem,
   			p.unimedida as punimed,
   			e.estfanta as estfanta,
   			p.pronivelb as pnivel, 
   			p.pronome as nomefilho, 
   			p.proplest as polfilho   		
   			from estrutur e 
   			inner join produto p on p.produto = e.estfilho 
   			where e.estproduto = pproduto
   	    	and p.proplest <> 'MTO'
   	    loop   	    
    		if rec.origem = 'F' and rec.fanta <> 'S'  and rec.estfanta = 'S' and (select engfanest from engparam where engparcod=1)='S' then 
    			rec.estfanta = 'M';
    		else
    			rec.estfanta = 'N';
    		end if;
    	    
    	        	    
    		select PLNSLDFIM
    		from planee_tmp p where p.plncodigo = pplano and p.plnprodut = pproduto into vqtduso ;
    		
    		pSldnecess1 = rec.pSldnecess * pqtdfinal; --vqtduso; 
	    	    			  			
			perform fn_grava_necessidade_mrpii17(pplano, rec.filho, rec.origem, rec.punimed, pSldnecess1, 0, 0, 0, 0,
			0, pdeonde, rec.nomefilho, rec.polfilho, rec.estfanta, rec.pnivel, rec.grupo, rec.subgrupo);  
   			   		
   	    end loop;
   	     
   	end if;
    
    --drop table tmp_mrp;
    
    return retorno; 
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_busca_infos_mrpii(character, integer[], character, character, numeric, character, character, character, character, numeric, numeric, numeric, character, numeric, numeric, numeric, numeric, numeric, numeric, character, character, numeric, numeric, date, date, numeric, numeric) SET search_path=public, pg_temp;

ALTER FUNCTION fn_busca_infos_mrpii(character, integer[], character, character, numeric, character, character, character, character, numeric, numeric, numeric, character, numeric, numeric, numeric, numeric, numeric, numeric, character, character, numeric, numeric, date, date, numeric, numeric)
  OWNER TO postgres;
