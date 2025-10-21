-- View: pw_previsoes_pagamento_pedido_compra

-- DROP VIEW pw_previsoes_pagamento_pedido_compra;

CREATE OR REPLACE VIEW pw_previsoes_pagamento_pedido_compra AS 
 SELECT c.compra AS previsoespagamentopedidocompra_compra_codigo,
    p.compnum AS previsoespagamentopedidocompra_numero_parcela,
    p.compdata AS previsoespagamentopedidocompra_data_previsao_parcela,
    p.compvalor AS previsoespagamentopedidocompra_valor_parcela,
    p.valorantecipa AS previsoespagamentopedidocompra_valor_antecipacao_parcela,
    p.dataantecipa AS previsoespagamentopedidocompra_data_antecipacao_parcela
   FROM compra c
     JOIN LATERAL ( SELECT fn_previsoes_pagamento_pedido_compra.compnum,
            fn_previsoes_pagamento_pedido_compra.compdata,
            fn_previsoes_pagamento_pedido_compra.compvalor,
            fn_previsoes_pagamento_pedido_compra.valorantecipa,
            fn_previsoes_pagamento_pedido_compra.dataantecipa
           FROM fn_previsoes_pagamento_pedido_compra(c.compra, c.condicao) fn_previsoes_pagamento_pedido_compra(compnum, compdata, compvalor, valorantecipa, dataantecipa, compobs)) p ON true;

ALTER TABLE pw_previsoes_pagamento_pedido_compra
  OWNER TO postgres;
