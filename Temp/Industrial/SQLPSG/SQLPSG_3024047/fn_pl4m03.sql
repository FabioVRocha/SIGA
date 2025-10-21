-- Function: fn_pl4m03(character varying, text, numeric)

-- DROP FUNCTION fn_pl4m03(character varying, text, numeric);

CREATE OR REPLACE FUNCTION fn_pl4m03(cjson character varying, cusuario text, ccanalvenda numeric)
  RETURNS void AS
$BODY$
DECLARE
    cjsontxt JSON;
    cjsontxt2 JSON;
    jsonTam INTEGER;
    nn INTEGER := 1;
    ccodigopai text;
    ctemfilho text;
    maiorseq numeric;
    cexiste numeric;
    cmarca text;
    cdescri text;
    cid text;
    carvore text;
BEGIN
    -- Converte o parâmetro cjson em JSON
    cjsontxt = cjson::JSON;

    -- Obtém o número de elementos no array
    jsonTam = json_array_length(cjsontxt);

    maiorseq = coalesce((select umpefaped from umpedfat where umpefaest = cusuario order by umpefaped desc limit 1),1) + 1;
  
    -- Loop para iterar pelos elementos do JSON
    nn = 1;
    FOR cjsontxt2 IN (
        SELECT * FROM json_array_elements(cjsontxt)
    ) LOOP
        IF nn <= jsonTam THEN
            -- Extrai os valores dos campos no JSON
        	ccodigopai = cjsontxt2 ->> 'parent';
        	if ccodigopai = '#' then
        		ccodigopai = '';
        	end if;
        	ccodigopai = convert_to(ccodigopai, 'LATIN1'); -- Converte para LATIN1
        	
	        ctemfilho = cjsontxt2 ->> 'children';
	        if ctemfilho = 'true' then
	        	ctemfilho = '#' || ctemfilho;
	        end if;
	        ctemfilho = convert_to(ctemfilho, 'LATIN1'); -- Converte para LATIN1
	       
	        cdescri = cjsontxt2 ->> 'text';
	        --cdescri = regexp_replace(cdescri, E'[^\x01-\xFF]', '', 'g');
	        --if (select 1 where cdescri = ''
	        --cdescri = regexp_replace(cdescri, E'[^\x01-\xFF]', '', 'g');
	        
	        cid = convert_to(cjsontxt2 ->> 'id', 'LATIN1'); -- Converte para LATIN1
		
	        
	        cexiste = (select 1 from mrkp25 ml where ml.mrkp25idca = cid and ml.mrkp25idcv = ccanalvenda);
	        if cexiste = 1 then
	        	cmarca = '+';
	        else
	        	cmarca = ' ';
	        end if;
	       
	        carvore = '';
	        carvore = (select umpeflong from umpedfat u where u.umpefaest = cusuario and umpeconent = ccanalvenda and umpedesapl = ccodigopai limit 1);
	        if length(Trim(carvore)) > 0 then
	        	carvore = carvore || ' -> ' || substring(cdescri,1,50);
	        else
	        	carvore = substring(cdescri,1,50);
	        end if;
	        --carvore = '';
	       	
            INSERT INTO umpedfat (umpefaest, umpefaped, umpefaseq, umpeconent, umpedesapl, umpefades, umpefcnom, umpedocent, umpefamar, umpeflong)
            VALUES (
            	cusuario,
            	maiorseq,
            	1,
            	ccanalvenda,
                cid,
                substring(cdescri,1,50),
                ccodigopai,
                ctemfilho,
                cmarca,
                carvore
            );
            maiorseq = maiorseq + 1;
        ELSE
            EXIT;
        END IF;
        nn := nn + 1;
    END LOOP;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_pl4m03(character varying, text, numeric)
  OWNER TO postgres;
