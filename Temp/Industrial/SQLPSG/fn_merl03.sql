-- Function: fn_merl03(character, character varying, integer)

-- DROP FUNCTION fn_merl03(character, character varying, integer);

CREATE OR REPLACE FUNCTION fn_merl03(cusuario character, cjson character varying, nfilial integer)
  RETURNS void AS
$BODY$ -- Busca dados das compras e joga na tabela de ordem de compra MKRP01, depois e a mesma para buscar os itens da ordem de compra
DECLARE
  registro1 record;
  registro2 record;
  registro3 record;
  registro4 record;
  registro5 record;
  registro6 record;
  cselect varchar;
  cselect_id varchar;
  ccompra_id  char(32);  
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
   --If 1  = 2 then
   for registro1 in (select value as cvalue from json_each_text(cjsontxt) where key = 'results' ) loop
      --Pega o retorno json que esta no results e joga suas colunhas em linhas do regitro
      cselect       = registro1.cvalue;
      cselect_json1 = registro1.cvalue;
      If substring(cselect,1,1) = '[' then
         --Se o resultado e um array,  o results contem um array, cada linha do array e uma compra
         for registro2 in (select value as cvalue from json_array_elements(cselect_json1)  ) loop
            --Pega o retorno do array e lista linhas de json, ou seja, cada linha do array e um novo json que representa uma compra
            cselect_json2 = registro2.cvalue;
            nvalortot_com_frete = 0;
            nvalorfrete = 0;
            nvalortotal  = 0;
            nvalorpago = 0;
            for registro3 in ( select key as ckey, value as cvalue from json_each_text(cselect_json2) ) loop
               --Joga as colunas do arquivo json e linhas, ou seja, uma linha par cada coluna key nome da coluna, value valor da coluna
               If trim(registro3.ckey) = 'payments' then
                  --Pagamento da Compra e retornado em um array
   
               End If;

               If trim(registro3.ckey) = 'shipping' then
                  --ID do shipping para dados de Enivo para pegar em uma segunda consulta, pois nao vem mais os dados de endereco
                  cshipping_ID = (select value from json_each_text(registro3.cvalue::json) where key = 'id');
                  --crua = cshipping_ID;
               End If;
   
               If trim(registro3.ckey) = 'expiration_date' then
                  --Vencimento da Compra
                  dvencimento = substring(registro3.cvalue::text,1,10)::date;
               End If;
               If trim(registro3.ckey) = 'date_closed' then
                  --Fechamento da Compra
                  dfechamento = substring(registro3.cvalue::text,1,10)::date;
               End If;
               If trim(registro3.ckey) = 'id' then
	          --Codigo da Compra no Mercado Livre
                  ccompra_id = trim(registro3.cvalue::text);
                  nn = nn + 1;
               End If;
               If trim(registro3.ckey) = 'date_last_updated' then
	          --ultima alteracao
	          dultalt = substring(registro3.cvalue::text,1,10)::date;
                  hultalt = substring(registro3.cvalue::text,12,8);
               End If;
               If trim(registro3.ckey) = 'date_created' then
	          --ultima alteracao
	          dinclusao = substring(registro3.cvalue::text,1,10)::date;
                  hinclusao = substring(registro3.cvalue::text,12,8);
               End If;
               If trim(registro3.ckey) = 'total_amount_with_shipping' then
                  --Total da compra com o frete
                  nvalortot_com_frete = (registro3.cvalue::text)::numeric(15,2);
               End If;
               If trim(registro3.ckey) = 'status' then
                  cstatus = substring(registro3.cvalue::text,1,20);
                  --Status da Compra
                  --cstatus = registro3.cvalue::text;
                  --confirmed Status inicial de uma ordem; ainda sem ter sido paga.
                  --payment_required O pagamento da ordem deve ter sido confirmado para exibir as informacoes do usuario.
                  --payment_in_process a um pagamento relacionado a ordem, mais ainda nao foi creditado.
                  --partially_paid A ordem tem um pagamento associado creditado, porem, insuficiente.
                  --paid A ordem tem um pagamento associado creditado.
                  --cancelled Por alguma razao, a ordem nao foi completada.
                  --invalid A ordem foi invalidada por vir de um comprador malicioso.
               End If;  
               If trim(registro3.ckey) = 'shipping' then
                  --Dados / Endereco de entrega que esta dentro de um arquivo json, porem nao esta mais vindo nesta consulta
                  for registro5 in ( select key as ckey, value as cvalue from json_each_text(registro3.cvalue::json) ) loop
                     --If trim(registro5.ckey) = 'receiver_address' then
                     --   --ctxt = substring(registro5.cvalue::text,1,40);
                     --   --insert into umnotas (umntusuari, umntcontr, umntsistem, umntopera, umntsequen, umntobs, umntdepnom)
                     --   --             values (cusuario, ccompra_id::numeric, 'xxxx', 'xxxx', 1, ctxt, 'xx');
                     --   --Dados da entrega que esta dentro de outro arquivo json
                     --   for registro6 in (select key as ckey, value as cvalue from json_each_text(registro5.cvalue::json) ) loop
                     --     If registro6.ckey = 'city' then
                     --        --Cidade esta dentro de um json
                     --        ccidade = substring(( select value from json_each_text(registro6.cvalue::json) where key = 'name' ),1,40);
                     --     End If;
                     --     If registro6.ckey = 'street_name' then
                     --        crua =    substring(trim(registro6.cvalue),1,40);
                     --     End If;                          
                     --     If registro6.ckey = 'street_number' then
                     --        cnum =    trim(registro6.cvalue);
                     --        crua = trim(crua)+', N. '+trim(cnum);
                     --     End If;
                     --     If registro6.ckey = 'zip_code' then
                     --        ccep =    substring(trim(registro6.cvalue),1,9);
                     --     End If;  
                     --     If registro6.ckey = 'neighborhood' then
                     --        --Bairro esta dentro de um json
                     --        cbairro = substring(( select value from json_each_text(registro6.cvalue::json) where key = 'name' ),1,30);
                     --     End If;
                     --     If registro6.ckey = 'comment' then
                     --        --Bairro esta dentro de um json
                     --        ccomplem =  substring(trim(registro6.cvalue),1,40);
                     --     End If;
                     --     If registro6.ckey = 'state' then
                     --        --Estado esta dentro de um json
                     --        cestado = ( select value from json_each_text(registro6.cvalue::json) where key = 'id' );
                     --        cuf = substring(cestado,4,2);
                     --     End If;
                     --   end loop;
                     --End If;
                  end loop;
               End If;
               If trim(registro3.ckey) = 'buyer' then
                  --json com dados do comprador
                  ccliente_json = registro3.cvalue;
                  cprimeiro_nome = '';
                  cultimo_nome   = '';
                  cnome          = '';
                  ccomprador_ID  = '';
                  cemailcomprador = '';
                  for registro4 in ( select key as ckey, value as cvalue from json_each_text(ccliente_json) ) loop
                     If trim(registro4.ckey) = 'id' then
                        ccomprador_ID = registro4.cvalue::text;
                     End If;
                     If trim(registro4.ckey) = 'first_name' then
                        cultimo_nome = registro4.cvalue::text;
                     End If;
                     If trim(registro4.ckey) = 'last_name' then
                        cprimeiro_nome = registro4.cvalue::text;
                     End If;
                     If trim(registro4.ckey) = 'email' then
                        cemailcomprador = substring(registro4.cvalue::text,1,50);
                     End If;
                     If trim(registro4.ckey) = 'phone' then
                        --Telefone vem em um arquivo json
                        cfone = ( select value from json_each_text(registro4.cvalue::json) where key = 'area_code' ) ||' '||( select value from json_each_text(registro4.cvalue::json) where key = 'number' );
                     End If;
                     If trim(registro4.ckey) = 'billing_info' then
                        --Documentos vem em um arquivo json
                        ctipo_doc  = ( select value from json_each_text(registro4.cvalue::json) where key = 'doc_type' );
                        cdocumento = ( select value from json_each_text(registro4.cvalue::json) where key = 'doc_number' );
                     End If;
                  end loop;
                  cnome = trim(cprimeiro_nome)||' '||trim(cultimo_nome);
               End If;
  
               If trim(registro3.ckey) = 'total_amount' then
                  --Total da compra
                  nvalortotal = (registro3.cvalue::text)::numeric(15,2);
               End If;
  
               If trim(registro3.ckey) = 'paid_amount' then
                  --Total pago
                  nvalorpago = (registro3.cvalue::text)::numeric(15,2);
               End If;
            end loop;
            If nvalortot_com_frete > 0 then
               nvalorfrete = nvalortot_com_frete - nvalortotal;
            Else 
               nvalortot_com_frete = nvalortotal;
            End If;
            If ( select count(*) from mrkp01 where mrkidmrkp = 'MLB' and mrkidorca = ccompra_id ) = 0 then
               insert into mrkp01
                                 (mrkidmrkp, mrkidorca, mrkdtemis, mrkcoorca, mrkfilorca,   mrkdtvenc,     mrkidclie,       mrkemclie, mrkcodpes, mrknompes,  mrkcpfcnp, mrkendere, mrkbairro,
                                  mrkcomple, mrknocida, mrkestado, mrkcep, mrkfone,   mrkvlrorc,   mrkvlrfre,           mrkvlrtot, mrkmsgnli, mrkmkdtalt, mrkmkhralt, mrksmktatu,
                                  mrksidtinc, mrksihrinc, mrksiusuin, mrksubmrk, mrknoloja )
                          values ('MLB',    ccompra_id, dinclusao,         0,    nfilial, dvencimento, ccomprador_ID, cemailcomprador,         0,     cnome, cdocumento,      crua,   cbairro,
                                  ccomplem,   ccidade,       cuf,   ccep,   cfone, nvalortotal, nvalorfrete, nvalortot_com_frete,       ' ',    dultalt,    hultalt,    cstatus,
                                  ddtnula,     chrnula,       ' ', 'MLB', 'MLB');
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
                   where mrkidmrkp = 'MLB' and mrkidorca = ccompra_id;
            End If;
            If char_length(trim(cshipping_ID)) > 0 then
                If (select count(*) from mrkp20 where mrfoidmrk = 'MLB' and mrfodorca = ccompra_id and mrfoitseq = 0 ) = 0 then
                    insert into mrkp20 
                                      ( mrfoidmrk,  mrfodorca, mrfoitseq,   mrfoidetiq, mrfodtalt, mrfohralt, mrfousualt )
                               values (     'MLB', ccompra_id,         0, cshipping_ID,   dultalt,   hultalt, cusuario);
                Else
                    update mrkp20
                       set 
                       mrfoidetiq = mrfoidetiq, 
                       mrfodtalt  = mrfodtalt, 
                       mrfohralt  = hultalt, 
                       mrfousualt = cusuario
                       where mrfoidmrk = 'MLB' and mrfodorca = ccompra_id and mrfoitseq = 0;
                End if;               
            End If;  
         end loop;
      End If;
   end loop;
   --End If;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl03(character, character varying, integer)
  OWNER TO postgres;
