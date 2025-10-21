-- Function: fn_merl11(character, character varying)

-- DROP FUNCTION fn_merl11(character, character varying);

CREATE OR REPLACE FUNCTION fn_merl11(cestacao character, cjson character varying)
  RETURNS void AS
$BODY$-- Dados de mensagens. Sao listadas as mensagens (ID da Compra), depois devem ser pegos estes e buscados as mensagens
DECLARE   
  registro1 record;  
  registro2 record;  
  cjsontxt json;
  cselect  varchar;
  ctxtmsg varchar;
  cid_compra char(20); 
  nn numeric(3); 
BEGIN   
   cjsontxt = cjson;  
nn = 0;
   --delete from umgeral where umgesta = cestacao;
   delete from umaxilia where umaxestac = cestacao and umaxcampo = 'MRKP09';
   for registro1 in (select value as cvalue from json_each_text(cjsontxt) where key = 'results' ) loop      
      --retira do json o arquivo que sao os dados das mensagens dentro de um array
      cselect = registro1.cvalue;
      for registro2 in (select value from json_array_elements(cselect::json) ) loop   
          --cada linha do array e um json da mensagem
          ctxtmsg  = substring(trim((select value from json_each_text(registro2.value::json) where key = 'resource')::text),1,130);
          nn = nn +1;
          --insert into umgeral (UMGESTA, UMGCODI, UMGSEQ, UMGDESC )  
          --             values (cestacao, nn, 1, ctxtmsg) ;
          insert into umaxilia (umaxestac, umaxchave, umaxcampo, umaxconte )
                        values ( cestacao,  nn::text,  'MRKP09',   ctxtmsg ); 
      end loop;      
      --inser into
   end loop;
END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl11(character, character varying)
  OWNER TO postgres;
