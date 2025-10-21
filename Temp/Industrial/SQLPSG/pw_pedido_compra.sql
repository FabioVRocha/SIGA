-- View: pw_pedido_compra

-- DROP VIEW pw_pedido_compra;

CREATE OR REPLACE VIEW pw_pedido_compra AS 
 SELECT pp.compra AS pedidocompra_codigo_pk,
    ped.comtipo AS pedidocompra_tipo_compra_codigo_fk,
    ped.deposito AS pedidocompra_deposito_codigo_fk,
    ped.commodc AS pedidocompra_modcobranca_codigo_fk,
    ped.comdata AS pedidocompra_data_emissao,
    ped.comfatur AS pedidocompra_data_faturamento,
    ped.empresa AS pedidocompra_empresa_codigo_fk,
    ped.condicao AS pedidocompra_condicao_pagto_codigo_fk,
    pp.produto AS pedidocompra_produto_codigo_fk,
    pp.cmpseq AS pedidocompra_produto_sequencia,
    pp.cmpquanti AS pedidocompra_qtde_produto,
    round(prod.proqtdger * pp.cmpquanti, 4) AS pedidocompra_qtde_gerencial_produto,
    round(prod.proliqui * pp.cmpquanti, 4) AS pedidocompra_qtde_peso_liquido_produto,
    round(pp.cmptotpro + round(pp.cmptotpro * (pp.cmpipi / 100::numeric), 2) + pp.cmpvlicmst, 2) AS pedidocompra_valor_produto_total,
    pp.cmpunita AS pedidocompra_valor_produto_unitario,
    pp.cmpipi AS pedidocompra_valor_produto_ipi,
    pp.cmptotpro AS pedidocompra_valor_produto_subtotal,
    pp.cmpated AS pedidocompra_data_atendimento,
    ped.comaprova AS pedidocompra_situacao,
    pp.cmpstatus AS pedidocompra_status,
    pp.cmpprev AS pedidocompra_data_previsao,
    round(pp.cmpquanti - pp.cmpqatnf - pp.comqatend, 4) AS pedidocompra_saldo_item,
    pp.compra AS pedidocompra_pedidocompraobservacao_codigo_fk
   FROM compra3 pp
     LEFT JOIN ( SELECT produto.produto,
            produto.proqtdger,
            produto.proliqui
           FROM produto) prod ON pp.produto = prod.produto
     LEFT JOIN ( SELECT compra.compra,
            compra.deposito,
            compra.comdata,
            compra.comfatur,
            compra.comtipo,
            compra.condicao,
            compra.empresa,
            compra.commodc,
            compra.comaprova
           FROM compra) ped ON pp.compra = ped.compra;

ALTER TABLE pw_pedido_compra
  OWNER TO postgres;
