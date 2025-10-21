--View: pw_produto_historico_venda

-- DROP VIEW pw_produto_historico_venda;

CREATE OR REPLACE VIEW pw_produto_historico_venda AS
 SELECT pp.pedido AS produtohistoricovenda_pedido_venda_codigo_fk,
    ( SELECT hiscusto.hicuvlrcu
           FROM hiscusto
          WHERE hiscusto.hicuproco = pp.pprproduto AND (hiscusto.hicudepo = ped.deposito OR hiscusto.hicudepo = 0) AND hiscusto.hicudatal <= ped.peddata
          ORDER BY hiscusto.hicudatal DESC, hiscusto.hicuhoral DESC
         LIMIT 1) AS produtohistoricovenda_valor_produto_custorep_emissao,
    ( SELECT hiscusto.hicuvlrcu
           FROM hiscusto
          WHERE hiscusto.hicuproco = pp.pprproduto AND (hiscusto.hicudepo = ped.deposito OR hiscusto.hicudepo = 0) AND (hiscusto.hicudatal < 'now'::text::date OR hiscusto.hicudatal = 'now'::text::date AND hiscusto.hicuhoral < 'now'::text::time with time zone::character(8))
          ORDER BY hiscusto.hicudatal DESC, hiscusto.hicuhoral DESC
         LIMIT 1) AS produtohistoricovenda_valor_produto_custorep_atual,
    ( SELECT hiscusto.hicudatal
	   FROM hiscusto
	 WHERE hiscusto.hicuproco = pp.pprproduto AND (hiscusto.hicudepo = ped.deposito OR hiscusto.hicudepo = 0)
	 ORDER BY hiscusto.hicudatal DESC, hiscusto.hicuhoral DESC
        LIMIT 1) AS produtohistoricovenda_data_ultimo_custo
 FROM pedprodu pp
     LEFT JOIN ( SELECT pedido.pedido,
		pedido.deposito,
		pedido.peddata
	       FROM pedido
		LEFT JOIN ( SELECT DISTINCT ON (ve.coppedido) ve.coppedido,
                    ve.vendedor
                   FROM comiped ve) ven ON ven.coppedido = pedido.pedido) ped ON pp.pedido = ped.pedido
 ORDER BY pp.pedido DESC;
 
ALTER TABLE pw_produto_historico_venda
  OWNER TO postgres;