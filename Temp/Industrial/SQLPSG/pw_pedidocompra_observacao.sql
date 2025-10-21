-- View: pw_pedidocompra_observacao

-- DROP VIEW pw_pedidocompra_observacao;

CREATE OR REPLACE VIEW pw_pedidocompra_observacao AS 
 SELECT c.compra AS pedidocompraobservacao_codigo_pk,
    string_agg(c.comobs::text, ' '::text ORDER BY c.comseqobs) AS observacaopedidocompra_observacao
   FROM compra1 c
  GROUP BY c.compra
  ORDER BY c.compra DESC;

ALTER TABLE pw_pedidocompra_observacao
  OWNER TO postgres;
