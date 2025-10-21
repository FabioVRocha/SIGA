-- Function: fn_merl06(character, character varying)

-- DROP FUNCTION fn_merl06(character, character varying);

CREATE OR REPLACE FUNCTION fn_merl06(ccompra_id character, cjson character varying)
  RETURNS void AS
$BODY$-- Busca dados dos itens de uma compras e joga na tabela MRKP02.
DECLARE 
  registro1 record;
  registro2 record;
  registro3 record;
  registro4 record;
  registro5 record;
  registro6 record;
  registro7 record; --Para os pagamentos
  registro8 record; --Para variacao de acabamento
  cselect varchar;
  cselect_id varchar;  
  dultalt date;
  hultalt char(8);
  dinclusao date;
  hinclusao char(8);
  cselect_json1 json;
  cselect_json2 json;
  citens_json_array json;
  cpgto_json_array json; --Para os pagamentos
  cvaria_json_array json; --Para variacao de acabamento
  citens_json1 json;
  citens_json2 json;
  citens_txt varchar;
  cpgto_txt varchar; --Para os pagamentos   
  citens_txt2 varchar;
  citem_id char(20);
  ctipovar_id char(20);
  cvaria_id char(20);
  ctipovar1_cod char(2);
  cvaria1_cod char(6);
  ctipovar2_cod char(2);
  cvaria2_cod char(6);
  ccompvaria char(100);
  nvar numeric(3);
  citem_desc char(200);
  nquantidade numeric(12,3);
  nvlrunit_item numeric(15,2);
  nvlrtot_item numeric(15,2);
  nvlrcomi_ml numeric(15,2);
  cjsontxt json;
  nn numeric(3);
  ntam integer;
  nseqitem numeric(3);

  nseqitepgto numeric(3);  
  cid_forpgto char(30);   --ID da forma de Pagamento utilizada
  daprovacao date;        --Data da Aprovacao
  nvlrpgto numeric(15,2); --Valor do Pagamento
  cauto_code char(30);    --Codigo de autorizacao
  cid_pgto char(30);      --ID do Pagametno
  daltpgto date;          --Data de alteracao do Pagamento 
  haltpgto char(8);       --Hora de alteracao do Pagamento 
  cbandeira char(30);     --Banderia Cartao utilizado no Pagamento
  ctippgto char(30);      --Tipo de Pagamento utilizado
  cstatpgto char(30);     --Status do Pagamento utilizado  
  
  --cnn char(16);
BEGIN
   cjsontxt = cjson;
   nn       = 0;
   for registro1 in (select value as cvalue from json_each_text(cjsontxt) where key = 'results' ) loop
      --Pega o retorno json que esta no results
      cselect       = registro1.cvalue;
      cselect_json1 = registro1.cvalue;
      If substring(cselect,1,1) = '[' then
         --Se o resultado e um array
         for registro2 in (select value as cvalue from json_array_elements(cselect_json1)  ) loop
            --Pega o retorno do array e lista linhas de json, ou seja, cada linha do array e um novo json
            cselect_json2 = registro2.cvalue;
            for registro3 in ( select key as ckey, value as cvalue from json_each_text(cselect_json2) ) loop
               --Joga os dados do json em linhas, ou seja, cada linha vai ser uma coluna do arquivo
               If trim(registro3.ckey) = 'id' then
	          --Codigo da Compra no Mercado Livre
                  --ccompra_id = trim(registro3.cvalue::text);
                  nn = nn + 1;
               End If;
               nseqitem = 0;
               If  trim(registro3.ckey) = 'order_items' then
                  --json com os itens da compra
                  citens_json_array = registro3.cvalue;
                  citens_txt  = registro3.cvalue;
                  If substring(citens_txt,1,1) = '[' then
                     --Se o resultado e um array
                     for registro5 in (select value as cvalue from json_array_elements(citens_json_array)  ) loop
                        --Leitura registros do array, ou seja, cada linha do array e um arquivo json
                        citens_json1 = registro5.cvalue;
                        citens_txt2  = registro5.cvalue;
                        nquantidade = 0;
                        nvlrunit_item = 0;
                        nvlrcomi_ml   = 0;
                        for registro6 in (select key as ckey, value as cvalue from json_each_text(citens_json1)  ) loop
                           --Leitura dos dados do item da compra, ou seja, coloca em linhas as colunas do arquivo
                           If trim(registro6.ckey) = 'item' then
                              --Dados dos itens esta em um novo json e os comandos abaixo nao pegam as colunas necessarias, poderia jogar o json em registros, como anteriormente
                              --ou pegar direto os campos.
                              citem_id = trim((select value from json_each_text(registro6.cvalue::json) where key = 'id'));
                              --ntam = char_length(trim(citem_id)) - 3; Foi retirado, pois agora o MLB manda com MLB e cria o ID do item com MLB
                              --citem_id = substring(citem_id,4,ntam);
                              citem_desc = (select value from json_each_text(registro6.cvalue::json) where key = 'title');
                              cvaria_json_array = (select value from json_each_text(registro6.cvalue::json) where key = 'variation_attributes');                                                            
                              ctipovar1_cod = '  ';
                              cvaria1_cod   = '      ';
                              ctipovar2_cod = '  ';
                              cvaria2_cod   = '      ';
                              nvar         = 0;
                              ccompvaria    = '';
                              for registro8 in (select value as cvalue from json_array_elements(cvaria_json_array)  ) loop
                                  nvar = nvar + 1;                                  
                                  ctipovar_id  = trim(( select value from json_each_text(registro8.cvalue::json) where key = 'id')); 
                                  cvaria_id    = trim(( select value from json_each_text(registro8.cvalue::json) where key = 'value_id'));
                                  If nvar = 1 then
                                     ctipovar1_cod = (select mrtvcosis from mrkp16 where mrtvidtpv = ctipovar_id);
                                     cvaria1_cod   = (select mrvacosis from mrkp17 where mrvaidtpv = ctipovar_id and mrvaidvar = cvaria_id);                
                                     
                                  End If;
                                  If nvar = 2 then
                                     ctipovar2_cod = (select mrtvcosis from mrkp16 where mrtvidtpv = ctipovar_id);
                                     cvaria2_cod   = (select mrvacosis from mrkp17 where mrvaidtpv = ctipovar_id and mrvaidvar = cvaria_id);                
                                  End If;
                              end loop; 
                              If char_length(trim((ctipovar1_cod))) > 0 then
                                  ccompvaria = '_v_'||ctipovar1_cod||cvaria1_cod||'__'||ctipovar2_cod||cvaria2_cod;
                              End If;                           
                           End If;
                           If trim(registro6.ckey) = 'quantity' then
                              --Quantidade do item
                              nquantidade = registro6.cvalue::numeric(12,3);
                           End If;
                           If trim(registro6.ckey) = 'unit_price' then
                              --Valor Unitario do item
                              nvlrunit_item = registro6.cvalue::numeric(15,2);
                           End If;
                           If trim(registro6.ckey) = 'sale_fee' then
                              nvlrcomi_ml = registro6.cvalue::numeric(15,2);
                           End If;                          
                        end loop;                      
                        nseqitem = nseqitem +1;
                        If (select count(*) from mrkp02 where mritidmrk = 'MLB' and mritidorc = ccompra_id and mritsequ = nseqitem ) = 0 then
                           insert into mrkp02 (mritidmrk,           mritidorc, mritsequ, mritiditem, mritdeitem,  mritquanti,    mritvlruni, mritvlrcom, mritidvar)
                                       values (    'MLB', ccompra_id, nseqitem,   citem_id, citem_desc, nquantidade, nvlrunit_item, nvlrcomi_ml, ccompvaria);
  
                        Else
                           update mrkp02
                              set
                              mritiditem = citem_id,
                              mritdeitem = citem_desc,
                              mritquanti = nquantidade,
                              mritvlruni = nvlrunit_item,
                              mritvlrcom = nvlrcomi_ml,
                              mritidvar  = ccompvaria
                              Where mritidmrk = 'MLB' and mritidorc = ccompra_id and mritsequ = nseqitem;
                        End If;
                     end loop;
                  End If;
               End If; 
  
               --Para todos os itens que foram inseridos anteriormente, grava a data e hora da ultima alteracao.
               If trim(registro3.ckey) = 'date_last_updated' then
	          --Ultima alteracao
	          dultalt = substring(registro3.cvalue::text,1,10)::date;
                  hultalt = substring(registro3.cvalue::text,12,8);
                  update mrkp02
                            set
                            mritdtalt = dultalt,
                            mrithralt = hultalt
                            Where mritidmrk = 'MLB' and mritidorc = ccompra_id;
               End If;
               If trim(registro3.ckey) = 'date_created' then
	          --Ultima alteracao
	          dinclusao = substring(registro3.cvalue::text,1,10)::date;
                  hinclusao = substring(registro3.cvalue::text,12,8);
               End If;
               If trim(registro3.ckey) = 'payments' then
                  --Pagamentos que esta dentro de um array
                  -- https://www.mercadopago.com.br/developers/pt/reference/payments/resource/
                  -- Guarda os dados para no final processar os pagamentos.
                  cpgto_txt  = registro3.cvalue;
                  cpgto_json_array = registro3.cvalue;                                    
               End If;    
            end loop;
         end loop;         
      End If;   
   end loop;
   If substring(cpgto_txt,1,1) = '[' then
     --Se o resultado for um array, teve pagamentos
     for registro7 in (select value as cvalue from json_array_elements(cpgto_json_array)  ) loop
	--Leitura registros do array, ou seja, cada linha do array vai ser um arquivo json
	citem_desc  = trim((select value from json_each_text(registro7.cvalue::json) where key = 'reason')); --Descricao do item  
	nseqitepgto = (select mritsequ from mrkp02 where mritidmrk = 'MLB' and mritidorc = ccompra_id and mritdeitem = citem_desc ); --Busca seq do item
	cid_forpgto = (select value from json_each_text(registro7.cvalue::json) where key = 'payment_method_id'); --ID da forma de Pagamento utilizada
	daprovacao  = substring((select value from json_each_text(registro7.cvalue::json) where key = 'date_approved'),1,10)::date;  --Data da Aprovacao
	nvlrpgto    = (select value from json_each_text(registro7.cvalue::json) where key = 'transaction_amount')::numeric(15,2); --Valor do Pagamento
	cauto_code  = (select value from json_each_text(registro7.cvalue::json) where key = 'authorization_code'); --Codigo de autorizacao                        
	cid_pgto    = (select value from json_each_text(registro7.cvalue::json) where key = 'id'); --ID do Pagametno
	daltpgto    = substring((select value from json_each_text(registro7.cvalue::json) where key = 'date_last_modified'),1,10)::date; --Data de alteracao do Pagamento 
	haltpgto    = substring((select value from json_each_text(registro7.cvalue::json) where key = 'date_last_modified'),12,8); --Hora de alteracao do Pagamento 
	cbandeira   = (select value from json_each_text(registro7.cvalue::json) where key = 'payment_method_id'); --Banderia Cartao utilizado no Pagamento
	ctippgto    = (select value from json_each_text(registro7.cvalue::json) where key = 'payment_type'); --Tipo de Pagamento utilizado
	cstatpgto   = (select value from json_each_text(registro7.cvalue::json) where key = 'status'); --Status do Pagamento utilizado  
	If (select count(*) from mrkp03 where mrpgidmrk = 'MLB' and mrpgidorc = ccompra_id and mrpgseque = nseqitepgto and mrpgidfpg = cid_forpgto ) = 0 then
	    insert into mrkp03 (mrpgidmrk,  mrpgidorc,   mrpgseque,   mrpgidfpg,  mrpgdtapr, mrpgvlrpg,  mrpgcodau, mrpgidpag, mrpgdtalt, mrpghralt, mrpgcrban, mrpgtppag, mrpgstpag )
			values (    'MLB', ccompra_id, nseqitepgto, cid_forpgto, daprovacao,  nvlrpgto, cauto_code,  cid_pgto,  daltpgto,  haltpgto, cbandeira,  ctippgto, cstatpgto );
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
		      where mrpgidmrk = 'MLB' and mrpgidorc = ccompra_id and mrpgseque = nseqitepgto and mrpgidfpg = cid_forpgto;   
		   
	End If;

     end loop;   
  End If;   

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl06(character, character varying)
  OWNER TO postgres;
