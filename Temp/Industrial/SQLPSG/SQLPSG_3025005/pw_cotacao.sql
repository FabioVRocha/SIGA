-- View: pw_cotacao

-- DROP VIEW pw_cotacao;

CREATE OR REPLACE VIEW pw_cotacao AS 
 SELECT nco.ncotacao AS cotacao_codigo_cotacao_pk,
    nco1.ncotprod AS cotacao_produto_codigo_fk,
    nco1.ncotsaving AS cotacao_valor_unitario_inicial_produto,
    nco1.ncotunitar AS cotacao_valor_unitario_final_produto,
    nco1.ncotsaving - nco1.ncotunitar AS cotacao_valor_saving_produto,
    nco.ncotempr AS cotacao_empresa_codigo_fk,
    nco.ncotdata AS cotacao_data,
    nco1.ncotqtde AS cotacao_qtde_produto,
    fn_cotacao_tipo_pedido_compra(nco1.ncotped, nco.ncotcomp) AS cotacao_tipo_compra_codigo_fk,
    nco1.ncottoi AS cotacao_valor_total_produto
   FROM ncotacao nco
     JOIN ncotaca1 nco1 ON nco1.ncotacao = nco.ncotacao;

ALTER TABLE pw_cotacao
  OWNER TO postgres;
