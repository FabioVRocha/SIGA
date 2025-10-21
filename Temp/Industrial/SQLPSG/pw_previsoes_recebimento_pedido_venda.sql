-- View: pw_previsoes_recebimento_pedido_venda

-- DROP VIEW pw_previsoes_recebimento_pedido_venda;

CREATE OR REPLACE VIEW pw_previsoes_recebimento_pedido_venda AS 
 SELECT c.pedido AS previsoesrecebimentopedidovenda_venda_codigo,
    p.prenumero AS previsoesrecebimentopedidovenda_numero_parcela,
    p.predata AS previsoesrecebimentopedidovenda_data_previsao_parcela,
    p.prevalor AS previsoesrecebimentopedidovenda_valor_parcela,
    p.premodalidade::character(2) AS previsoesrecebimentopedidovenda_modalidade_cobranca,
    p.valorantecipa AS previsoesrecebimentopedidovenda_valor_antecipacao_parcela,
    p.dataantecipa AS previsoesrecebimentopedidovenda_data_antecipacao_parcela
   FROM pedido c
     JOIN LATERAL ( SELECT fn_previsoes_recebimento_pedido_venda.prenumero,
            fn_previsoes_recebimento_pedido_venda.predata,
            fn_previsoes_recebimento_pedido_venda.prevalor,
            fn_previsoes_recebimento_pedido_venda.premodalidade,
            fn_previsoes_recebimento_pedido_venda.valorantecipa,
            fn_previsoes_recebimento_pedido_venda.dataantecipa
           FROM fn_previsoes_recebimento_pedido_venda(c.pedido, c.pedcondica) fn_previsoes_recebimento_pedido_venda(prenumero, predata, prevalor, premodalidade, dataantecipa, valorantecipa)) p ON true;

ALTER TABLE pw_previsoes_recebimento_pedido_venda
  OWNER TO postgres;
