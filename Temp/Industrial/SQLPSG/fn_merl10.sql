-- Function: fn_merl10(character, character varying)

-- DROP FUNCTION fn_merl10(character, character varying);

CREATE OR REPLACE FUNCTION fn_merl10(ccompra_id character, cjson character varying)
  RETURNS void AS
$BODY$
-- Inclusao MSG conforme json retornado
DECLARE   
  registro1 record;  
  cjsontxt json;
  ctxtmsg varchar;
  cid_msg varchar;    
  dultalt date;
  hultalt char(8);
  chor char(2);
  cmin char(2);
  cseg char(2);
  ctimestamp char(30);
  ttimestamp timestamp;
BEGIN   
   cjsontxt = cjson;  
   for registro1 in (select key as ckey, value as cvalue from json_each_text(cjsontxt)) loop      
      --Faz a leitura das linhas do joson que contem as informacoes
      If trim(registro1.ckey) = 'id' then
         cid_msg = trim(registro1.cvalue);
      End If;
      If trim(registro1.ckey) = 'text' then 
         ctxtmsg = trim(registro1.cvalue);
      End If;
      If trim(registro1.ckey) = 'message_date' then
         ctimestamp  = (select value from json_each_text(registro1.cvalue::json) where key = 'created'); --Retira o datatime do json
         ttimestamp = (select timezone('UTC3',ctimestamp::timestamp with time zone));        
         dultalt     = date(ttimestamp);
         chor        = date_part('hour', ttimestamp)::char(2);
         cmin        = date_part('minute', ttimestamp)::char(2);
         cseg        = date_part('second', ttimestamp)::char(2);
         hultalt     = lpad(chor,2,'0') || ':' || lpad(cmin,2,'0') || ':' || lpad(cseg,2,'0');
         hultalt     = replace(hultalt,'.','0');
      End If;
   end loop;          
          
   insert into mrkp09 (mrmsidmrk,  mrmsidorc, mrmsidmsg, mrmstipms, mrmsmensg, mrmsdtalt, mrmshralt )  
               values (    'MLB', ccompra_id, cid_msg  ,       'E',   ctxtmsg,   dultalt, hultalt   ) ;

END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl10(character, character varying)
  OWNER TO postgres;
