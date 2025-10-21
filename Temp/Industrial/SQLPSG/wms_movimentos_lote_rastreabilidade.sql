-- View: wms_movimentos_lote_rastreabilidade

-- DROP VIEW wms_movimentos_lote_rastreabilidade;

CREATE OR REPLACE VIEW wms_movimentos_lote_rastreabilidade AS 
select t.toqrasras as movimentosloterastreabilidade_movimento_loterastreabilidade_codigo_pk, 
	   t.toqrascon as movimentosloterastreabilidade_movimento_controle_pk,
	   t.toqrasseq as movimentosloterastreabilidade_movimento_sequencia_pk,
	   t.toqraspro as movimentosloterastreabilidade_movimento_produto_codigo,
	   t.toqrasdat as movimentosloterastreabilidade_movimento_data,
	   t.toqrastra as movimentosloterastreabilidade_movimento_transacao,
	   t.toqrasqtd as movimentosloterastreabilidade_movimento_qtde,
	   t.toqrasdep as movimentosloterastreabilidade_movimento_deposito_codigo
from toqrastr t
order by movimentosloterastreabilidade_movimento_loterastreabilidade_codigo_pk, movimentosloterastreabilidade_movimento_controle_pk, movimentosloterastreabilidade_movimento_sequencia_pk,
movimentosloterastreabilidade_movimento_produto_codigo
;

ALTER TABLE wms_movimentos_lote_rastreabilidade
  OWNER TO postgres;