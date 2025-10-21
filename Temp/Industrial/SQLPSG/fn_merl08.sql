-- Function: fn_merl08(character, character varying, character, character)

-- DROP FUNCTION fn_merl08(character, character varying, character, character);

CREATE OR REPLACE FUNCTION fn_merl08(cusuario character, cjson character varying, cidcompra character, cmodo character)
  RETURNS void AS
$BODY$-- Dados manutencao de uma anotacao de uma compra e inclui na tabela de anotacoes
DECLARE   
  registro1 record;  
  cselect  varchar;
  cjsontxt json;    
  cidmsg char(50);
  ctxtmsg char(300);
  ddtcreate date;
  chrcreate char(8);
  ddtaltera date;
  chraltera char(8);
  cid_compra char(20);  
  chor char(2);
  cmin char(2);
  cseg char(2);
  ctimestamp char(30);
  ttimestamp timestamp;
BEGIN   
   cjsontxt = cjson;  
   If trim(cmodo) = 'INS' then
      --Anclusao de msg          
      cselect    = (select value from json_each_text(cjsontxt) where key = 'note' );         
      cid_compra = cidcompra;   
      cidmsg     = substring((select value from json_each_text(cselect::json) where key = 'id')::text,1,50); 

      ctimestamp  = (select value from json_each_text(cselect::json) where key = 'date_created')::text; --Retira o datatime do json
      ttimestamp = (select timezone('UTC3',ctimestamp::timestamp with time zone));        
      ddtcreate     = date(ttimestamp);
      chor        = date_part('hour', ttimestamp)::char(2);
      cmin        = date_part('minute', ttimestamp)::char(2);
      cseg        = date_part('second', ttimestamp)::char(2);
      chrcreate   = lpad(chor,2,'0') || ':' || lpad(cmin,2,'0') || ':' || lpad(cseg,2,'0');            
      ctimestamp  = (select value from json_each_text(cselect::json) where key = 'date_last_updated')::text; --Retira o datatime do json
      ttimestamp = (select timezone('UTC3',ctimestamp::timestamp with time zone));        
      ddtaltera     = date(ttimestamp);
      chor        = date_part('hour', ttimestamp)::char(2);
      cmin        = date_part('minute', ttimestamp)::char(2);
      cseg        = date_part('second', ttimestamp)::char(2);
      chraltera   = lpad(chor,2,'0') || ':' || lpad(cmin,2,'0') || ':' || lpad(cseg,2,'0');
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

   Elsif trim(cmodo) = 'UPD' then
      --Alteracao da msg
      cselect    = (select value from json_each_text(cjsontxt) where key = 'note' );         
      cid_compra = cidcompra;   
      cidmsg     = substring((select value from json_each_text(cselect::json) where key = 'id')::text,1,50); 
      
      ctimestamp  = (select value from json_each_text(cselect::json) where key = 'date_created')::text; --Retira o datatime do json
      ttimestamp = (select timezone('UTC3',ctimestamp::timestamp with time zone));        
      ddtcreate     = date(ttimestamp);
      chor        = date_part('hour', ttimestamp)::char(2);
      cmin        = date_part('minute', ttimestamp)::char(2);
      cseg        = date_part('second', ttimestamp)::char(2);
      chrcreate   = lpad(chor,2,'0') || ':' || lpad(cmin,2,'0') || ':' || lpad(cseg,2,'0');            

      ctimestamp  = (select value from json_each_text(cselect::json) where key = 'date_last_updated')::text; --Retira o datatime do json
      ttimestamp = (select timezone('UTC3',ctimestamp::timestamp with time zone));        
      ddtaltera     = date(ttimestamp);
      chor        = date_part('hour', ttimestamp)::char(2);
      cmin        = date_part('minute', ttimestamp)::char(2);
      cseg        = date_part('second', ttimestamp)::char(2);
      chraltera   = lpad(chor,2,'0') || ':' || lpad(cmin,2,'0') || ':' || lpad(cseg,2,'0');
      
      ctxtmsg    = substring((select value from json_each_text(cselect::json) where key = 'note'),1,300); 
      update mrkp04
             set mrandesc  = ctxtmsg, 
                 mrandtalt = ddtaltera, 
                 mranhralt = chraltera
             where mranidmrk = 'MLB' and mranidorc = cid_compra and mranidano = cidmsg;
              
      -- update set = ddtaltera, =chraltera, = ctxtmsg
      -- where = cid_compra and = cidmsg 
   Elsif trim(cmodo) = 'DLT' then
      cselect    = (select value from json_each_text(cjsontxt) where key = 'message' ); 
      If trim(cselect) = 'Note deleted ok' then
        -- delete from mrkp04
        --        where mranidmrk = 'MLB' and mranidorc = cid_compra and mranidano = cidmsg; 
        --Deletar a msg
        -- delete from 
        -- where = cid_compra and = cidmsg 
      End If;     
   End If; 
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl08(character, character varying, character, character)
  OWNER TO postgres;
