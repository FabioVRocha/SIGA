-- View: pw_posicao_caixa

-- DROP VIEW pw_posicao_caixa;

CREATE OR REPLACE VIEW pw_posicao_caixa AS 

select
	p.pcdata as posicaocaixa_data_posicao,
	p.pcadeposit as posicaocaixa_deposito_codigo_fk,
	p.pcasaldo as posicaocaixa_valor_saldo
from
	pcaixa p
order by
	p.pcdata;

ALTER TABLE pw_posicao_caixa
OWNER TO postgres;