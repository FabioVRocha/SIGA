-- Function: fn_merl12(character varying, character, character)

-- DROP FUNCTION fn_merl12(character varying, character, character);

CREATE OR REPLACE FUNCTION fn_merl12(cjson character varying, cid_pk_ord_msg character, cid_user_vend character)
  RETURNS void AS
$BODY$-- Baixar mensagens 
DECLARE   
  registro1 record;  
  registro2 record;  
  cjsontxt json;
  cjsontxt2 json;
  cselect  varchar;
  ctxtmsg varchar;
  ctxtdate varchar;
  cidmsg char(50);
  ddtcreate date;
  chrcreate char(8);
  ddtaltera date;
  chraltera char(8);
  cid_compra char(20); 
  cid_user_from   char(20);
  ctipmsg char(1);
  chor char(2);
  cmin char(2);
  cseg char(2);
  ctimestamp char(30);
  ttimestamp timestamp;
BEGIN   
   cjson := REPLACE(cjson, E'\n', '');
   cjsontxt = cjson;  
   cid_compra = cid_pk_ord_msg;
   for registro1 in (select key as ckey, value as cvalue from json_each_text(cjsontxt) where key = 'messages' ) loop      
      --retira do json o arquivo que sao os dados das mensagens dentro de um array
      cselect   = registro1.cvalue;             
      for registro2 in (select value from json_array_elements(cselect::json) ) loop   
          --cada linha do array e um json da mensagem com seu campos                            
             
          cjsontxt2 = (select value from json_each_text(registro2.value) where key = 'from'); 
          cid_user_from = ( select value from json_each_text(cjsontxt2) where key = 'user_id' );          
          cidmsg     = trim((select value from json_each_text(registro2.value::json) where key = 'id')::text);
          ctxtmsg    = trim((select value from json_each_text(registro2.value::json) where key = 'text')::text);
          ctimestamp  = (select value from json_each_text((trim((select value from json_each_text(registro2.value::json) where key = 'message_date')::text))::json) where key = 'created'); --Retira o datatime do json
          ttimestamp = (select timezone('UTC3',ctimestamp::timestamp with time zone));        
          ddtcreate     = date(ttimestamp);
          chor        = date_part('hour', ttimestamp)::char(2);
          cmin        = date_part('minute', ttimestamp)::char(2);
          cseg        = date_part('second', ttimestamp)::char(2);
          chrcreate   = lpad(chor,2,'0') || ':' || lpad(cmin,2,'0') || ':' || lpad(cseg,2,'0');
          chrcreate     = replace(chrcreate,'.','0');
          If trim(cid_user_from) = trim(cid_user_vend) then
             --Quando o remetente da msg for o mesmo do vendedor, mensagem e de envio
             ctipmsg = 'E';
          Else
             --Quando o remetente da msg for diferente do vendedor, mensagem e de recebimento
             ctipmsg = 'R'; 
          End If;
          If ( select count(*) from mrkp09 where mrmsidmrk = 'MLB'and mrmsidorc = cid_compra and mrmsidmsg = cidmsg ) = 0 then
              insert into mrkp09 (mrmsidmrk,  mrmsidorc, mrmsidmsg, mrmstipms, mrmsmensg, mrmsdtalt, mrmshralt )  
                          values (    'MLB', cid_compra, cidmsg  ,   ctipmsg,   ctxtmsg,  ddtcreate, chrcreate ) ;
          Else
              update mrkp09
                        set 
                        mrmstipms = ctipmsg,
                        mrmsmensg = ctxtmsg,
                        mrmsdtalt = ddtcreate,
                        mrmshralt = chrcreate
                        where mrmsidmrk = 'MLB'and mrmsidorc = cid_compra and mrmsidmsg = cidmsg;
          End If;               
      end loop;      

   end loop;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl12(character varying, character, character)
  OWNER TO postgres;
