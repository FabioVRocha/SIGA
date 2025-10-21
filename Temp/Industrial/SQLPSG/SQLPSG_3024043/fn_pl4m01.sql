-- Function: fn_pl4m01(character, character varying, integer)

-- DROP FUNCTION fn_pl4m01(character, character varying, integer);

CREATE OR REPLACE FUNCTION fn_pl4m01(cestacao character, cjson character varying, nfilial integer)
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
  ccompra_id  char(100);
  ccompra_id2 char(100);
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
  cjsontxt2 json;
  jsonTam numeric(5);
  cshippingName char(50);
  ctrackingNumber char(50);
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
  select
		MAX(case when key = 'id' then value end) as id,
		MAX(case when key = 'saleChannel' then value end) as saleChannel,
		MAX(case when key = 'saleChannelName' then value end) as saleChannel,
		MAX(case when key = 'shipping' then value end) as shipping,
		MAX(case when key = 'createdAt' then substring(value::text,1,10)::date end) as createdAt,
		MAX(case when key = 'createdAt' then substring(value::text,12,8) end) as createdAtHora,
		MAX(case when key = 'updatedAt' then substring(value::text,1,10)::date end) as updatedAt,
		MAX(case when key = 'updatedAt' then substring(value::text,12,8) end) as updatedAtHora,
		MAX(case when key = 'status' then value end) as status,
		MAX(case when key = 'totalAmount' then value::numeric(15,2) end) as totalAmount,
		MAX(case when key = 'shippingCost' then value::numeric(15,2) end) as shippingCost,
		MAX(case when key = 'shipment' then value end) as shipment
		
		into
		ccompra_id, --Id
		csubmarketplace, --SaleChannel
		clojamarketplace, --saleChannelName
		cselect_json1, --shipping
		dinclusao, --createdAt
		hinclusao, --createdAtHora
		dultalt,   --updatedAt
        hultalt,   --updatedAtHora
		cstatus, --status
		nvalortot_com_frete, --totalAmount
		nvalorfrete, --shippingCost
		cselect_json2 --shipment
	from json_each_text 
    	(cjsontxt) as json_data;
    
    nvalortotal = nvalortot_com_frete - nvalorfrete; --Valor total sem o frete
     
 --Endereco de Entrega
 for registro2 in (select key as ckey, value as cvalue from json_each_text(cselect_json1::json) ) loop
   	If trim(registro2.ckey) = 'recipientName' then
       cnome  = trim(registro2.cvalue);
    End If;
    If trim(registro2.ckey) = 'phone' then   
       --Fone do Comprador
       cfone  = trim(registro2.cvalue);
    End If; 
	 If trim(registro2.ckey) = 'street' then
       --Rua
       crua  = trim(registro2.cvalue);
    End If; 
    If registro2.ckey = 'streetNumber' then
       cnum =    trim(registro2.cvalue);
       crua = trim(crua)||', N. '||trim(cnum);
    End If;
    If trim(registro2.ckey) = 'district' then   
       --Bairo
       cbairro = trim(registro2.cvalue);
    End If; 
    If trim(registro2.ckey) = 'streetComplement' then
       --Complemento
       ccomplem = trim(registro2.cvalue);
    End If; 
    If trim(registro2.ckey) = 'city' then   
       --Cidade
       ccidade = trim(registro2.cvalue);
    End If; 
    If trim(registro2.ckey) = 'state' then   
       --UF
       cuf = trim(registro2.cvalue);
    End If;
    If trim(registro2.ckey) = 'zipCode' then
       --CEP
       ccep = trim(registro2.cvalue);
    End If;                       
 end loop;
  
   dvencimento = ddtnula;
   ccomprador_ID = '';
   cemailcomprador = '';
   cdocumento = '';
   If character_length(ccompra_id) <> 0 then                   
      If ( select count(*) from mrkp01 where mrkidmrkp = 'PLUG4MARKET' and mrkidorca = ccompra_id ) = 0 then
         insert into mrkp01
                           (mrkidmrkp, mrkidorca, mrkdtemis, mrkcoorca, mrkfilorca,   mrkdtvenc,     mrkidclie,       mrkemclie, mrkcodpes, mrknompes,  mrkcpfcnp, mrkendere, mrkbairro,
                            mrkcomple, mrknocida, mrkestado, mrkcep, mrkfone,   mrkvlrorc,   mrkvlrfre,           mrkvlrtot, mrkmsgnli, mrkmkdtalt, mrkmkhralt, mrksmktatu,
                            mrksidtinc, mrksihrinc, mrksiusuin, mrksubmrk, mrknoloja )
                    values ('PLUG4MARKET',    ccompra_id, dinclusao,         0,    nfilial, dvencimento, ccomprador_ID, cemailcomprador,         0,     cnome, cdocumento,      crua,   cbairro,
                             ccomplem,   ccidade,       cuf,   ccep,   cfone, nvalortotal, nvalorfrete, nvalortot_com_frete,       ' ',    dultalt,    hultalt,    cstatus,
                             ddtnula,     chrnula,       ' ', csubmarketplace, clojamarketplace );
                            
         insert into umaxilia (umaxestac, umaxchave, umaxcampo, umaxconte )
                        values ( cestacao,  1::text,  'MRKP01',   ccompra_id );                              
                            
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
            where mrkidmrkp = 'PLUG4MARKET' and mrkidorca = ccompra_id;
          
          insert into umaxilia (umaxestac, umaxchave, umaxcampo, umaxconte )
                        values ( cestacao,  1::text,  'MRKP01',   ccompra_id );  
      End If;

     --Leitura dos itens     
     nseqitem = 0;
     nn = 1;
     jsonTam = json_array_length(cjsontxt::json -> 'orderItems'); --Busca Quantas posicoes tem o JSON
	 for cjsontxt2 in (select * from json_array_elements(cjsontxt::json -> 'orderItems') ) loop --Faz um laco para ler todas as posicoes
	    if nn <= jsonTam then
		    --= cjsontxt2 -> 'orderItemId'; -- numerico nao vira entre aspas, entao nao preciso de dois ">>"
		    citem_desc = cjsontxt2 ->> 'name';
		    --= cjsontxt2 -> 'mainImage';
		    nquantidade= cjsontxt2 -> 'quantity';
		    --= cjsontxt2 -> 'total';
		    --= cjsontxt2 -> 'price';
		    --= cjsontxt2 -> 'discount';
		    --= cjsontxt2 -> 'freight';
		    --= cjsontxt2 -> 'salePrice';
		    --= cjsontxt2 -> 'unitDiscount';
		    nvlrunit_item = cjsontxt2 -> 'originalPrice';
		    --= cjsontxt2 -> 'originalTotal';
		    citem_id = cjsontxt2 ->> 'productId';
		    citem_id_var = cjsontxt2 ->> 'sku';
		    --= cjsontxt2 -> 'customId';
		   	
		   
			 If character_length(citem_desc) = 0 or trim(citem_desc) = trim(citem_id) or trim(citem_desc) = trim(citem_id_var) then
		        --Buscar a descricao do item quando ela nao estiver preenchida ou a descricao estiver com o codigo do item.         
		        citem_desc = (select pronome from produto where produto = citem_id); 
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
		     
		     nseqitem = nseqitem + 1;
		     If (select count(*) from mrkp02 where mritidmrk = 'PLUG4MARKET' and mritidorc = ccompra_id and mritsequ = nseqitem ) = 0 then
		        insert into mrkp02 (mritidmrk,           mritidorc, mritsequ, mritiditem, mritdeitem,  mritquanti,    mritvlruni, mritvlrcom, mritdtalt, mrithralt, mritidvar)
		                    values (    'PLUG4MARKET', ccompra_id, nseqitem,   citem_id, citem_desc, nquantidade, nvlrunit_item, nvlrcomi_ml, dultalt, hultalt, ccompvaria);
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
		           Where mritidmrk = 'PLUG4MARKET' and mritidorc = ccompra_id and mritsequ = nseqitem;
		     End If;
	  	else
		   exit;
      	end If;
        nn = nn + 1;
	 end loop;
     --Leitura dos pagamentos
     nn = 1;
     jsonTam = json_array_length(cjsontxt::json -> 'paymentMethods'); --Busca Quantas posicoes tem o JSON
	 for cjsontxt2 in (select * from json_array_elements(cjsontxt::json -> 'paymentMethods') ) loop -- Faz um laco para ler todas as posicoes
	    if nn <= jsonTam then
	    	cid_forpgto = 'SeqPgto-'||nn::text;
		    ctippgto = cjsontxt2 ->> 'method'; -- numerico nao vira entre aspas, entao nao preciso de dois ">>"
		    nvlrpgto = cjsontxt2 -> 'value';
		    --= cjsontxt2 -> 'installments';
		    --= cjsontxt2 -> 'sequential';
		    cbandeira = cjsontxt2 ->> 'cardBrand';
		    cauto_code = cjsontxt2 ->> 'authorization';
		    cid_pgto = cjsontxt2 ->> 'authorization';
		    daprovacao = Current_date;
		   	
		    --Leitura registros do array, ou seja, cada linha do array vai ser um arquivo json
		   	cstatpgto = ' ';
	        If character_length(cauto_code) > 0 then 
	           cstatpgto = 'approved'; 
	        End If;
		        
			If (select count(*) from mrkp03 where mrpgidmrk = 'PLUG4MARKET' and mrpgidorc = ccompra_id and mrpgseque = 0 and mrpgidfpg = cid_forpgto ) = 0 then
			    insert into mrkp03 (mrpgidmrk,  mrpgidorc,   mrpgseque,   mrpgidfpg,  mrpgdtapr, mrpgvlrpg,  mrpgcodau, mrpgidpag, mrpgdtalt, mrpghralt, mrpgcrban, mrpgtppag, mrpgstpag )
					values (    'PLUG4MARKET', ccompra_id,         0, cid_forpgto, daprovacao,  nvlrpgto, cauto_code,  cid_pgto,  daltpgto,  haltpgto, cbandeira,  ctippgto, cstatpgto );
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
				      where mrpgidmrk = 'PLUG4MARKET' and mrpgidorc = ccompra_id and mrpgseque = 0 and mrpgidfpg = cid_forpgto;   
				   
			End If;
		 else
		   exit;
        end If;
        nn = nn + 1;
      end loop;
     
     --Dados da Transportadora
	 for registro3 in (select key as ckey, value as cvalue from json_each_text(cselect_json2::json) ) loop
	   	If trim(registro3.ckey) = 'trackingNumber' then
	   		--Código de Rastreio disponibilizado pela transportadora
	       ctrackingNumber  = trim(registro3.cvalue);
	    End If;
	    If trim(registro3.ckey) = 'shippingName' then   
	       --Nome da Transportador
	       cshippingName  = trim(registro3.cvalue);
	    End If; 
	 end loop;
	
		If (select count(*) from mrkp20 m where mrfoidmrk = 'PLUG4MARKET' and mrfodorca = ccompra_id and mrfoitseq = 0 ) = 0 then
		    insert into mrkp20 (mrfoidmrk, mrfodorca, mrfoitseq, mrfonotra, mrfocoras)
				values (    'PLUG4MARKET', ccompra_id,         0, cshippingName, ctrackingNumber);
		Else
		    update mrkp20
			      set 
			      mrfonotra = cshippingName,
			      mrfocoras = ctrackingNumber
			      where mrfoidmrk = 'PLUG4MARKET' and mrfodorca = ccompra_id and mrfoitseq = 0;   
		End If;
   End If;   
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_pl4m01(character, character varying, integer)
  OWNER TO postgres;
