-- Function: fn_merl05(character, character, character varying, integer)

-- DROP FUNCTION fn_merl05(character, character, character varying, integer);

CREATE OR REPLACE FUNCTION fn_merl05(cusuario character, ccompra_id character, cjson character varying, nfilial integer)
  RETURNS void AS
$BODY$ -- Busca dados de endeerco e valor da entrega
DECLARE
  registro1 record;
  registro2 record;  
  cselect varchar;
  cselect_id varchar;
  ccomprador_ID char(32);
  cshipping_ID char(30);
  cemailcomprador char(200);
  dvencimento date;
  dfechamento date;
  ddtnula date;
  dultalt date;
  hultalt char(8);
  chrnula char(8);
  dinclusao date;
  hinclusao char(8);
  cstatus char(20);
  cselect_json1 json;
  cselect_json2 json;
  ccliente_json json;
  cprimeiro_nome char(40);
  cultimo_nome char(40);
  cnome char(40);
  ctipo_doc char(4);
  cdocumento char(20);
  cfone char(14);
  crua char(40);
  ccidade char(40);
  cnum char(10);
  ccep char(9);
  cbairro char(30);
  ccomplem char(40);
  cestado char(40);
  cuf char(2);
  cjsontxt json;
  ctxt char(50);
  nn numeric(3);
  nvalortot_com_frete numeric(15,2);
  nvalorfrete numeric(15,2);
  nvalortotal numeric(15,2);
  nvalorpago numeric(15,2);
BEGIN 
   cjsontxt = cjson;
   nn       = 0;
   ddtnula = '0001-01-01'::date;
   nvalorfrete = 0;
   for registro1 in (select key as ckey, value as cvalue from json_each_text(cjsontxt) where key = 'receiver_address' OR key = 'shipping_option' ) loop      
      If trim(registro1.ckey) = 'receiver_address' then
         --Dados da entrega que esta dentro de outro arquivo json
         for registro2 in (select key as ckey, value as cvalue from json_each_text(registro1.cvalue::json) ) loop
            If registro2.ckey = 'city' then
               --Cidade esta dentro de um json
               ccidade = substring(( select value from json_each_text(registro2.cvalue::json) where key = 'name' ),1,40);
            End If;
            If registro2.ckey = 'street_name' then
               crua =    substring(trim(registro2.cvalue),1,40);
            End If;                          
            If registro2.ckey = 'street_number' then
               cnum =    trim(registro2.cvalue);
               crua = trim(crua)||', N. '||trim(cnum);
            End If;
            If registro2.ckey = 'zip_code' then
               ccep =    substring(trim(registro2.cvalue),1,9);
            End If;  
            If registro2.ckey = 'neighborhood' then
               --Bairro esta dentro de um json
               cbairro = substring(( select value from json_each_text(registro2.cvalue::json) where key = 'name' ),1,30);
            End If;
            If registro2.ckey = 'comment' then
	       --Bairro esta dentro de um json
               ccomplem =  substring(trim(registro2.cvalue),1,40);
            End If;
            If registro2.ckey = 'state' then
               --Estado esta dentro de um json
               cestado = ( select value from json_each_text(registro2.cvalue::json) where key = 'id' );
               cuf = substring(cestado,4,2);
            End If;
         end loop;         
      End If;           
      If trim(registro1.ckey) = 'shipping_option' then   
         cselect_json1 = registro1.cvalue::json;
         nvalorfrete = ( select value from json_each_text(cselect_json1) where key = 'cost' )::numeric(15,2);         
      End If;                
   end loop;   
   
            --If ( select count(*) from mrkp01 where mrkidmrkp = 'MLB' and mrkidorca = ccompra_id ) = 0 then
            --   insert into mrkp01
            --                     (mrkidmrkp, mrkidorca, mrkdtemis, mrkcoorca, mrkfilorca,   mrkdtvenc,     mrkidclie,       mrkemclie, mrkcodpes, mrknompes,  mrkcpfcnp, mrkendere, mrkbairro,
            --                      mrkcomple, mrknocida, mrkestado, mrkcep, mrkfone,   mrkvlrorc,   mrkvlrfre,           mrkvlrtot, mrkmsgnli, mrkmkdtalt, mrkmkhralt, mrksmktatu,
            --                      mrksidtinc, mrksihrinc, mrksiusuin, mrksubmrk, mrknoloja )
            --              values ('MLB',    ccompra_id, dinclusao,         0,    nfilial, dvencimento, ccomprador_ID, cemailcomprador,         0,     cnome, cdocumento,      crua,   cbairro,
            --                      ccomplem,   ccidade,       cuf,   ccep,   cfone, nvalortotal, nvalorfrete, nvalortot_com_frete,       ' ',    dultalt,    hultalt,    cstatus,
            --                      ddtnula,     chrnula,       ' ', 'MLB', 'MLB');
            --Else
		update mrkp01 
		   set
		   --mrkdtemis  = dinclusao,
                   --mrkfilorca = nfilial,
                   --mrkdtvenc  = dvencimento,
                   --mrkidclie  = ccomprador_ID,
                   --mrkemclie  = cemailcomprador,
                   --mrknompes  = cnome,
                   --mrkcpfcnp  = cdocumento,
                   mrkendere  = crua,
                   mrkbairro  = cbairro,
                   mrkcomple  = ccomplem,
                   mrknocida  = ccidade,
                   mrkestado  = cuf,
                   mrkcep     = ccep,
                   --mrkfone    = cfone
                   --mrkvlrorc  = nvalortotal,
                   mrkvlrfre  = nvalorfrete,
                   mrkvlrtot  = mrkvlrorc + nvalorfrete
                  where mrkidmrkp = 'MLB' and mrkidorca = ccompra_id;
            --End If;  

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl05(character, character, character varying, integer)
  OWNER TO postgres;
