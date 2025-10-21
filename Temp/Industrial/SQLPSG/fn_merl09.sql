-- Function: fn_merl09(character, character varying, character, character)

-- DROP FUNCTION fn_merl09(character, character varying, character, character);

CREATE OR REPLACE FUNCTION fn_merl09(cestacao character, cjson character varying, cmodo character, cidcompra character)
  RETURNS void AS
$BODY$-- Dados de feedbaks de uma compras e inclui na tabela de anotacoes
DECLARE   
  registro1 record;  
  cselect  varchar;
  cjsontxt json;    
  cidmsg char(20);
  cavalia char(20);
  ccoment char(300);
  ctxtmsg char(300);
  ddtcreate date;
  chrcreate char(8);
  ddtaltera date;
  chraltera char(8);
  cid_compra char(20);  
BEGIN   
   cjsontxt = cjson;  
   for registro1 in (select value as cvalue from json_each_text(cjsontxt) where key = 'purchase' ) loop      
      --retira do json o arquivo que e do comprador
      cselect = registro1.cvalue;
      cidmsg  = trim((select value from json_each_text(cselect::json) where key = 'id')::text);
      cavalia = trim((select value from json_each_text(cselect::json) where key = 'rating')::text);
      ccoment = trim((select value from json_each_text(cselect::json) where key = 'message')::text);
      ddtaltera  = substring((select value from json_each_text(cselect::json) where key = 'date_created')::text,1,10)::date; 
      chraltera  = substring((select value from json_each_text(cselect::json) where key = 'date_created')::text,12,8);  
      --inser into
   end loop;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl09(character, character varying, character, character)
  OWNER TO postgres;
