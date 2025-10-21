-- public.pw_ordem_compra source

CREATE OR REPLACE VIEW public.pw_ordem_compra
AS SELECT 
	RQCCOD as ordemcompra_codigo_pk,
	PRODUTO as ordemcompra_produto_codigo_fk,
	RQCDTEMI as ordemcompra_data_emissao,
	RQCDTATE as ordemcompra_data_atendimento,
	RQCQUANTI as ordemcompra_qtde,
	RQCPRIORI as ordemcompra_codigo_prioridade,
	RQCDPRIORI as ordemcompra_descricao_prioridade,
	FUNCIONA as ordemcompra_funcionario_codigo_fk,
	RQCFINALID as ordemcompra_finalidade,
	RQCDTREL as ordemcompra_data_impressa,
	RQCPREVI as ordemcompra_data_previsao,
	RQCPEDID as ordemcompra_codigo_pedido,
	p.COMDATA as ordemcompra_data_pedido,
	RQCSALDO as ordemcompra_qtde_saldo,
	RQCFORCOD as ordemcompra_empresa_codigo_fk,
	RQCPLANEJ as ordemcompra_planejamento,
	RQCDEPOS as ordemcompra_deposito_codigo_fk,
	RQCSTATUS as ordemcompra_status,
	RQCAUTOR as ordemcompra_usuario_liberou,
	RQCPEDVE as ordemcompra_pedidovenda_codigo_fk,
	RQCAUTDT as ordemcompra_data_liberacao,
	RQCAUTHR as ordemcompra_hora_liberacao,
	RQCASSIS as ordemcompra_assistencia_codigo_fk,
	RQCDTREPLA as ordemcompra_data_replanejamento_previsao,
	RQCUNICONV as ordemcompra_unidade_conversao,
	RQCQTDCONV as ordemcompra_quantidade_conversao,
	RQCTIPOPED as ordemcompra_tipocompra_codigo_fk,
	RQCCOCONTA as ordemcompra_contacontabil_codigo_fk,
	RQCCCUSTO as ordemcompra_centrocusto_codigo_fk
   FROM reqcomp r 
   inner join compra p on p.compra = r.rqcpedid 
  ORDER BY 1;
  ALTER TABLE pw_ordem_compra
  OWNER TO postgres;