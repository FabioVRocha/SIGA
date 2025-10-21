-- View: wms_lote_rastreabilidade

-- DROP VIEW wms_lote_rastreabilidade;

CREATE OR REPLACE VIEW wms_lote_rastreabilidade AS 
select l.ltracodig as loterastreabilidade_codigo_pk,
	   case
	   	when l.ltratipos = 'F' then 'Fabricação'
	   	else 'Compra'
	   end as loterastreabilidade_tipo,
	   l.ltradescr as loterastreabilidade_descricao,
	   l.ltraprodu as loterastreabilidade_produto_codigo,
	   l.ltradtent as loterastreabilidade_data_entrada,
	   l.ltradtvct as loterastreabilidade_data_validade,
	   l.ltradepos as loterastreabilidade_deposito_codigo,
	   l.ltrasaldo as loterastreabilidade_saldo_disponivel
from lotrast l 
order by loterastreabilidade_codigo_pk desc, loterastreabilidade_tipo
;

ALTER TABLE wms_lote_rastreabilidade
  OWNER TO postgres;