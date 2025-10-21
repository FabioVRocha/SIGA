-- Function: fn_pl4m02(character varying, text)

-- DROP FUNCTION fn_pl4m02(character varying, text);

CREATE OR REPLACE FUNCTION fn_pl4m02(cjson character varying, cusuario text)
  RETURNS void AS
$BODY$
DECLARE
    cjsontxt JSON;
    cjsontxt2 JSON;
    jsonTam INTEGER;
    nn INTEGER := 1;
    ccodigopai text;
    ctemfilho text;
BEGIN
    -- Converte o parâmetro cjson em JSON
    cjsontxt = cjson::JSON;

    -- Obtém o número de elementos no array
    jsonTam = json_array_length(cjsontxt);

    -- Loop para iterar pelos elementos do JSON
    FOR cjsontxt2 IN (
        SELECT * FROM json_array_elements(cjsontxt)
    ) LOOP
        IF nn <= jsonTam THEN
            -- Extrai os valores dos campos no JSON
        	ccodigopai = cjsontxt2 ->> 'parent';
        	if ccodigopai = '#' then
        		ccodigopai = '';
        	end if;
	        ctemfilho = cjsontxt2 ->> 'children';
	        if ctemfilho = 'true' then
	        	ctemfilho = '#' || ctemfilho;
	        end if;
            INSERT INTO mrkp10 (mrcasidmrk, mrcaidcmk, mrcadecmk, mrcadtalt, mrcahralt, mrcausalt, mrcaidpai, mrcaidalt, mrcafilho)
            VALUES (
            	'PLUG4MARKET',
                cjsontxt2 ->> 'id',
                cjsontxt2 ->> 'text',
                current_date::date,
                LPAD(SUBSTRING(current_time::text, 1, 8), 8, '0'),
                cusuario,
                ccodigopai,
                cjsontxt2 ->> 'alternativeId',
                ctemfilho
            );
        ELSE
            EXIT;
        END IF;
        nn := nn + 1;
    END LOOP;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_pl4m02(character varying, text)
  OWNER TO postgres;
