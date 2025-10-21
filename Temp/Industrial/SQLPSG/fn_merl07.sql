-- Function: fn_merl07(character, character varying, character, character)

-- DROP FUNCTION fn_merl07(character, character varying, character, character);

CREATE OR REPLACE FUNCTION fn_merl07(cusuario character, cjson character varying, cidcompra character, cmodo character)
  RETURNS void AS
$BODY$-- Dados de anotacoes de uma compra e inclui na tabela de anotacoes
DECLARE   
  registro1 record;  
  registro2 record;  
  cjsontxt json;    
  cjsontxt1 json;
  cid_compra char(20);  
  cidmsg char(30);
  ctxtmsg char(300);
  ddtcreate date;
  chrcreate char(8);
  ddtaltera date;
  chraltera char(8);
  cselect  varchar;
  chor char(2);
  cmin char(2);
  cseg char(2);
  ctimestamp char(30);
  ttimestamp timestamp;  
BEGIN   
   cjsontxt = cjson;  
   cid_compra = cidcompra;   
   for registro1 in (select value as cvalue from json_array_elements(cjsontxt)  ) loop 
      --Tira do json de anotacoes o array que tem uma posicao para cada ordem, no caso, vai ser uma ordem
      cjsontxt1 = (select value from json_each_text(registro1.cvalue) where key = 'results' ); --joga dentro de um novo json o array com todas as anotacoes
      for registro2 in (select value as cvalue from json_array_elements(cjsontxt1::json) ) loop
         --Faz a leitura de todas as anotacoes
         cselect    = registro2.cvalue;
         cidmsg     = substring((select value from json_each_text(cselect::json) where key = 'id')::text,1,30); 

         ctimestamp  = (select value from json_each_text(cselect::json) where key = 'date_created'); --Retira o datatime do json
         ttimestamp  = (select timezone('UTC3',ctimestamp::timestamp with time zone));        
         ddtcreate   = date(ttimestamp);
         chor        = date_part('hour', ttimestamp)::char(2);
         cmin        = date_part('minute', ttimestamp)::char(2);
         cseg        = date_part('second', ttimestamp)::char(2);
         chrcreate   = lpad(chor,2,'0') || ':' || lpad(cmin,2,'0') || ':' || lpad(cseg,2,'0');


         ctimestamp  = (select value from json_each_text(cselect::json) where key = 'date_last_updated'); --Retira o datatime do json
         ttimestamp  = (select timezone('UTC3',ctimestamp::timestamp with time zone));        
         ddtaltera   = date(ttimestamp);
         chor        = date_part('hour', ttimestamp)::char(2);
         cmin        = date_part('minute', ttimestamp)::char(2);
         cseg        = date_part('second', ttimestamp)::char(2);
         chraltera   = lpad(chor,2,'0') || ':' || lpad(cmin,2,'0') || ':' || lpad(cseg,2,'0');
         


         --ddtaltera  = substring((select value from json_each_text(cselect::json) where key = 'date_last_updated')::text,1,10)::date; 
         --chraltera  = substring((select value from json_each_text(cselect::json) where key = 'date_last_updated')::text,12,8);  
         
         ctxtmsg    = substring((select value from json_each_text(cselect::json) where key = 'note'),1,300); 
         If (select count(*) from mrkp04 where mranidmrk = 'MLB' and mranidorc = cid_compra and mranidano = cidmsg ) = 0 then
            insert into mrkp04 (mranidmrk,  mranidorc, mranidano, mrandtinc, mranhrinc, mrandesc, mrandtalt, mranhralt  )
                        values (    'MLB', cid_compra,    cidmsg, ddtcreate, chrcreate,  ctxtmsg, ddtaltera, chraltera );
         Else
            update mrkp04
                set mrandesc  = ctxtmsg, 
                    mrandtalt = ddtaltera, 
                    mranhralt = chraltera
                where mranidmrk = 'MLB' and mranidorc = cid_compra and mranidano = cidmsg;
         End If;    
      end loop;	
   end loop;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl07(character, character varying, character, character)
  OWNER TO postgres;
