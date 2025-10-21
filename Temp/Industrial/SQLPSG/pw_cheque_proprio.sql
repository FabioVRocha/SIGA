-- View: pw_cheque_proprio

-- DROP VIEW pw_cheque_proprio;

CREATE OR REPLACE VIEW pw_cheque_proprio AS 
select
	banco as chequeproprio_banco_codigo_fk, 	
	chdtlanca as chequeproprio_data_emissao, 
	chdtprevi as chequeproprio_data_previsao,
	chdeposito as chequeproprio_deposito_codigo_fk, 
	chnumero as chequeproprio_numero,
	chvalor as chequeproprio_valor_cheque,
	chhisto as chequeproprio_historico,
	chdata as chequeproprio_data_compensacao
from
	chpredat c
where
	chtipo like 'P'
order by
	chdtlanca; 
ALTER TABLE pw_cheque_proprio
  OWNER TO postgres;