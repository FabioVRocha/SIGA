-- Function: fn_sky01(character, character varying, integer)

-- DROP FUNCTION fn_sky01(character, character varying, integer);

CREATE OR REPLACE FUNCTION fn_sky01(cestacao character, cjson character varying, nfilial integer)
  RETURNS void AS
$BODY$ -- Busca dados das compras e joga na tabela de ordem de compra MKRP01, depois e a mesma para buscar os itens da ordem de compra
DECLARE
  registro1 record;
  registro2 record;
  registro3 record;
  registro4 record;
  registro5 record;
  registro6 record;
  registro7 record;
  registro8 record;
  cselect varchar;
  cselect_id varchar;
  ccompra_id  char(32);
  ccompra_id2 char(32);
  ccomprador_ID char(32);
  cemailcomprador char(200);
  csubmarketplace char(10);
  clojamarketplace char(100);
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
  cselect_json3 json;  
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
  nn integer;
  n2 integer;
  ntam integer;
  nseqitem numeric(3);
  cid_forpgto char(20);
  nvlrpgto numeric(15,2);
  daprovacao date;
  daltpgto date;
  haltpgto char(8);
  cbandeira char(30);
  cauto_code char(30);
  ctippgto char(30);
  cid_pgto char(20);
  cstatpgto char(30);
  nseqpag numeric(3);
  nvalortot_com_frete numeric(15,2);
  nvalorfrete numeric(15,2);
  nvalortotal numeric(15,2);
  citem_id char(20);
  citem_id_var char(100);
  citem_desc char(200);  
  ccompvaria char(100);
  nvar integer;
  ntmvar integer;
  nquantidade numeric(12,3);
  nvlrunit_item numeric(15,2);
  nvlrcomi_ml numeric(15,2);
BEGIN 
   cjsontxt = cjson;
   nn       = 0;
   ddtnula = '0001-01-01'::date;   
   nvalortot_com_frete = 0;
   nvalorfrete = 0;
   nvalortotal  = 0;
   nvlrpgto = 0;

   --delete from umgeral where umgesta = cestacao;
   delete from umaxilia where umaxestac = cestacao and umaxcampo = 'MRKP01';
   --Para incluir o codigo ID da Compra e confirmar depois como ja baixada
     
   for registro1 in (select key as ckey, value as cvalue from json_each_text(cjsontxt)) loop
      --Pega o retorno json que esta no results e joga suas colunhas em linhas do regitro      
      If trim(registro1.ckey) = 'code' then
          --Código ID da Compra
         cselect_id  = trim(registro1.cvalue);
         ccompra_id2 = trim(registro1.cvalue);
         nn          = (select position('-' in (cselect_id)));
         csubmarketplace = 'MARKETPLAC';
         clojamarketplace = 'MARKETPLACE';
         If nn > 0 then	      
            nn         = nn + 1;  --Depois do '-'
            n2         = nn - 2;  --Antes do '-'
            ntam       = character_length(cselect_id);
            ntam       = (ntam - nn) + 1 ;
            ccompra_id = substring(cselect_id::text,nn,ntam);
            csubmarketplace = substring(cselect_id,1,10);
            clojamarketplace = substring(cselect_id,1,n2);              
         Else
            ccompra_id = substring(ccompra_id2);
         End If;    
      End If;     
      If trim(registro1.ckey) = 'placed_at' then 
         --Data e hora de inclusao
         dinclusao = substring(registro1.cvalue::text,1,10)::date;
         hinclusao = substring(registro1.cvalue::text,12,8);
      End If;
      --Não tem informacao de vencimento
      dvencimento = ddtnula;
      If trim(registro1.ckey) = 'updated_at' then                 
         dultalt = substring(registro1.cvalue::text,1,10)::date;
         hultalt = substring(registro1.cvalue::text,12,8);
      End If;
      If trim(registro1.ckey) = 'status' then                 
         --Status 
         cstatus = ( select value from json_each_text(registro1.cvalue::json) where key ='type');       
      End If;   
      If trim(registro1.ckey) = 'total_ordered' then   
         nvalortotal         = (registro1.cvalue::text)::numeric(15,2);
         nvalortot_com_frete = nvalortotal;
         nvalorfrete         = 0;
      End If; 
      If trim(registro1.ckey) = 'shipping_cost' then   
         nvalorfrete   =  (registro1.cvalue::text)::numeric(15,2);
         nvalortotal   = nvalortotal - nvalorfrete;
      End If; 
      
      --nvalortotal, nvalorfrete, nvalortot_com_frete   
       
      If trim(registro1.ckey) = 'customer' then 
         --Dados do comprador cliente
         for registro2 in (select key as ckey, value as cvalue from json_each_text(registro1.cvalue::json)  ) loop
            If trim(registro2.ckey) = 'vat_number' then
               --ID do comprador que usa o documento
               ccomprador_ID    = trim(registro2.cvalue);
               cdocumento       = trim(registro2.cvalue);
            End If;
            If trim(registro2.ckey) = 'email' then   
               --Email do comprador 
               cemailcomprador  = trim(registro2.cvalue);
            End If;    
            If trim(registro2.ckey) = 'phones' then   
               --Fone do comprador 
               for registro4 in (select value from json_array_elements(trim(registro2.cvalue)::json)) loop
               --cfone  = (select value from json_array_elements(trim(registro2.cvalue)::json) limit 1);
                  cfone = registro4.value;
                  cfone = replace(cfone,'"','');
               end loop;
            End If;             
            If trim(registro2.ckey) = 'name' then   
               --Nome do comprador 
               cnome  = trim(registro2.cvalue);
            End If;  
         end loop; 
      End If;    
      If trim(registro1.ckey) = 'shipping_address' then 
         --Endereco de Entrega
         for registro3 in (select key as ckey, value as cvalue from json_each_text(registro1.cvalue::json)  ) loop
            If trim(registro3.ckey) = 'street' then   
               --Rua
               crua  = trim(registro3.cvalue);
            End If; 
            If registro3.ckey = 'street_number' then
               cnum =    trim(registro3.cvalue);
               crua = trim(crua)+', N. '+trim(number);
            End If;
            If trim(registro3.ckey) = 'neighborhood' then   
               --Bairo
               cbairro = trim(registro3.cvalue);
            End If; 
            If trim(registro3.ckey) = 'detail' then   
               --Complemento
               ccomplem = trim(registro3.cvalue);
            End If; 
            If trim(registro3.ckey) = 'city' then   
               --Cidade
               ccidade = trim(registro3.cvalue);
            End If; 
            If trim(registro3.ckey) = 'region' then   
               --UF
               cuf = trim(registro3.cvalue);
            End If;
            If trim(registro3.ckey) = 'postcode' then   
               --CEP
               ccep = trim(registro3.cvalue);
            End If;                       
         end loop;          
      End If;    
      If trim(registro1.ckey) = 'payments' then 
         nseqpag = 0;
         cselect_json2 = trim(registro1.cvalue); --Array com os pagametos
      End If;   
      If trim(registro1.ckey) = 'items' then    
         nseqitem = 0;
         cselect_json1 = trim(registro1.cvalue); --Array com os itens
      End If;
   End Loop;

   If character_length(ccompra_id) <> 0 then                   
      If ( select count(*) from mrkp01 where mrkidmrkp = 'SKYHUB' and mrkidorca = ccompra_id ) = 0 then
         insert into mrkp01
                           (mrkidmrkp, mrkidorca, mrkdtemis, mrkcoorca, mrkfilorca,   mrkdtvenc,     mrkidclie,       mrkemclie, mrkcodpes, mrknompes,  mrkcpfcnp, mrkendere, mrkbairro,
                            mrkcomple, mrknocida, mrkestado, mrkcep, mrkfone,   mrkvlrorc,   mrkvlrfre,           mrkvlrtot, mrkmsgnli, mrkmkdtalt, mrkmkhralt, mrksmktatu,
                            mrksidtinc, mrksihrinc, mrksiusuin, mrksubmrk, mrknoloja )
                    values ('SKYHUB',    ccompra_id, dinclusao,         0,    nfilial, dvencimento, ccomprador_ID, cemailcomprador,         0,     cnome, cdocumento,      crua,   cbairro,
                             ccomplem,   ccidade,       cuf,   ccep,   cfone, nvalortotal, nvalorfrete, nvalortot_com_frete,       ' ',    dultalt,    hultalt,    cstatus,
                             ddtnula,     chrnula,       ' ', csubmarketplace, clojamarketplace );
                           
         --insert into umgeral (UMGESTA, UMGCODI, UMGSEQ, UMGDESC )  
         --             values (cestacao, 1, 1, ccompra_id2) ;     
         insert into umaxilia (umaxestac, umaxchave, umaxcampo, umaxconte )
                        values ( cestacao,  1::text,  'MRKP01',   ccompra_id2 );                              
                            
      Else
         update mrkp01 
            set
            mrkdtemis  = dinclusao,
            mrkfilorca = nfilial,
            mrkdtvenc  = dvencimento,
            mrkidclie  = ccomprador_ID,
            mrkemclie  = cemailcomprador,
            mrknompes  = cnome,
            mrkcpfcnp  = cdocumento,
            mrkendere  = crua,
            mrkbairro  = cbairro,
            mrkcomple  = ccomplem,
            mrknocida  = ccidade,
            mrkestado  = cuf,
            mrkcep     = ccep,
            mrkfone    = cfone,
            mrkvlrorc  = nvalortotal,
            mrkvlrfre  = nvalorfrete,
            mrkvlrtot  = nvalortot_com_frete,
            mrksmktatu = cstatus
            where mrkidmrkp = 'SKYHUB' and mrkidorca = ccompra_id;
          
          --insert into umgeral (UMGESTA, UMGCODI, UMGSEQ, UMGDESC )  
          --            values (cestacao, 1, 1, ccompra_id2) ;            
          insert into umaxilia (umaxestac, umaxchave, umaxcampo, umaxconte )
                        values ( cestacao,  1::text,  'MRKP01',   ccompra_id2 );  
      End If;

    --Leitura dos itens         
   
      for registro5 in (select value as cvalue from json_array_elements(cselect_json1::json)  ) loop
         for registro6 in (select key as ckey, value as cvalue from json_each_text(registro5.cvalue::json)  ) loop
            If trim(registro6.ckey) = 'product_id' then
                --Codigo do Item
               citem_id = trim(registro6.cvalue);
            End If;
            If trim(registro6.ckey) = 'id' then
                --Codigo do Item com a variacao
               citem_id_var = trim(registro6.cvalue);
            End If;                              
            If trim(registro6.ckey) = 'name' then
               --Descricao do Item
               citem_desc = trim(registro6.cvalue);
            End If;   
            If trim(registro6.ckey) = 'qty' then
               --Quantidade do item
               nquantidade = trim(registro6.cvalue)::numeric(12,3);
            End If;   
            If trim(registro6.ckey) = 'original_price' then
               --Valor Unitário do item
               nvlrunit_item = trim(registro6.cvalue)::numeric(12,3);
            End If;                     
            If trim(registro6.ckey) = 'comissao' then
               --Comissao do Marketplace
               --nvlrcomi_ml = trim(registro6.cvalue)::numeric(12,3);
            End If; 
         end loop;         
         If character_length(citem_desc) = 0 or trim(citem_desc) = trim(citem_id) or trim(citem_desc) = trim(citem_id_var) then
            --Buscar a descricao do item quando ela nao estiver preenchida ou a descricao estiver com o codigo do item.         
            citem_desc = (select pronome from item where produto = citem_id); 
         End If;   
         If citem_id <> citem_id_var and ( select position(citem_id in (citem_id_var))) > 0 then
            --Para quando vir a variacao de acabamento junto com o codigo na variavel citem_id_var            
            nvar = (select position('_v_' in (citem_id_var)));
            If nvar > 0 then
                ntmvar = character_length(citem_id_var);
                ntmvar  = (ntmvar - nvar) + 1 ;
                ccompvaria = substring(citem_id_var,nvar,ntmvar); 
            Else
                citem_id = trim(citem_id_var);
            End If;    
         End if;
         
         nseqitem = nseqitem +1;
         If (select count(*) from mrkp02 where mritidmrk = 'SKYHUB' and mritidorc = ccompra_id and mritsequ = nseqitem ) = 0 then
            insert into mrkp02 (mritidmrk,           mritidorc, mritsequ, mritiditem, mritdeitem,  mritquanti,    mritvlruni, mritvlrcom, mritdtalt, mrithralt, mritidvar)
                        values (    'SKYHUB', ccompra_id, nseqitem,   citem_id, citem_desc, nquantidade, nvlrunit_item, nvlrcomi_ml, dultalt, hultalt, ccompvaria);
         Else
            update mrkp02
               set
               mritiditem = citem_id,
               mritdeitem = citem_desc,
               mritquanti = nquantidade,
               mritvlruni = nvlrunit_item,
               mritvlrcom = nvlrcomi_ml,
               mritdtalt  = dultalt,
               mrithralt  = hultalt,
               mritidvar  = ccompvaria
               Where mritidmrk = 'SKYHUB' and mritidorc = ccompra_id and mritsequ = nseqitem;
         End If;
      end loop;

      --Leitura dos pagamentos
      for registro7 in (select value as cvalue from json_array_elements(cselect_json2)  ) loop
	--Leitura registros do array, ou seja, cada linha do array vai ser um arquivo json
	nseqpag     = nseqpag + 1;
	cid_forpgto = 'SeqPgto-'||nseqpag::text; --(select value from json_each_text(registro7.cvalue::json) where key = 'payment_method_id'); --ID da forma de Pagamento utilizada
	nvlrpgto    = (select value from json_each_text(registro7.cvalue::json) where key = 'value')::numeric(15,2); --Valor do Pagamento
        daprovacao  = substring((select value from json_each_text(registro7.cvalue::json) where key = 'transaction_date'),1,10)::date;  --Data da Aprovação

        ctippgto    = '';  --Tipo de Pagamento utilizado	
        cbandeira   = '';  --Banderia Cartao utilizado no Pagamento
        cstatpgto   = '';
        
        cselect_json3 = (select value from json_each_text(registro7.cvalue::json) where key = 'sefaz')::json;
        cbandeira   = (select value from json_each_text(cselect_json3::json) where key = 'name_card_issuer'); --Banderia Cartao utilizado no Pagamento
        ctippgto    = (select value from json_each_text(cselect_json3::json) where key = 'name_payment'); --Tipo de Pagamento utilizado
        

        --Caso nao veio no grupo sefaz
        If character_length(cbandeira) = 0 then  
           cbandeira   = (select value from json_each_text(registro7.cvalue::json) where key = 'card_issuer'); --Banderia Cartão utilizado no Pagamento
	End If;
        --Caso nao veio no grupo sefaz
	If character_length(ctippgto) = 0 then
	   ctippgto    = (select value from json_each_text(registro7.cvalue::json) where key = 'method'); --Tipo de Pagamento utilizado
	End If;   
   
        cauto_code  = (select value from json_each_text(registro7.cvalue::json) where key = 'autorization_id'); --Codigo de autorizacao                        
	cid_pgto    = (select value from json_each_text(registro7.cvalue::json) where key = 'autorization_id'); --ID do Pagametno
	
        daltpgto    = substring((select value from json_each_text(registro7.cvalue::json) where key = 'transaction_date'),1,10)::date; --Data de alteracao do Pagamento 
	haltpgto    = substring((select value from json_each_text(registro7.cvalue::json) where key = 'transaction_date'),12,8); --Hora de alteracao do Pagamento 
	cstatpgto   = (select value from json_each_text(registro7.cvalue::json) where key = 'status'); --Status do Pagamento utilizado  

        If character_length(cauto_code) > 0 and ( character_length(cstatpgto) = 0  or cstatpgto is null ) then 
           cstatpgto = 'approved';           
        End If;   
        
	If (select count(*) from mrkp03 where mrpgidmrk = 'SKYHUB' and mrpgidorc = ccompra_id and mrpgseque = 0 and mrpgidfpg = cid_forpgto ) = 0 then
	    insert into mrkp03 (mrpgidmrk,  mrpgidorc,   mrpgseque,   mrpgidfpg,  mrpgdtapr, mrpgvlrpg,  mrpgcodau, mrpgidpag, mrpgdtalt, mrpghralt, mrpgcrban, mrpgtppag, mrpgstpag )
			values (    'SKYHUB', ccompra_id,         0, cid_forpgto, daprovacao,  nvlrpgto, cauto_code,  cid_pgto,  daltpgto,  haltpgto, cbandeira,  ctippgto, cstatpgto );
	Else
	    update mrkp03
		      set 
		      mrpgdtapr = daprovacao,
		      mrpgvlrpg = nvlrpgto,
		      mrpgcodau = cauto_code,
		      mrpgidpag = cid_pgto,
		      mrpgdtalt = daltpgto,
		      mrpghralt = haltpgto,
		      mrpgcrban = cbandeira,
		      mrpgtppag = ctippgto,
		      mrpgstpag = cstatpgto
		      where mrpgidmrk = 'SKYHUB' and mrpgidorc = ccompra_id and mrpgseque = 0 and mrpgidfpg = cid_forpgto;   
		   
	End If;

     end loop; 

      
   End If;   
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_sky01(character, character varying, integer)
  OWNER TO postgres;
