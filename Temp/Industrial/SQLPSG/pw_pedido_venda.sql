-- View: pw_pedido_venda

-- DROP VIEW pw_pedido_venda;

CREATE OR REPLACE VIEW pw_pedido_venda AS 
 SELECT pp.pedido AS pedidovenda_codigo_pk,
    ped.tipoped AS pedidovenda_tipo_venda_codigo_fk,
    ped.deposito AS pedidovenda_deposito_codigo_fk,
    ped.pedregca AS pedidovenda_regiao_carga_codigo_fk,
    ped.pedoperaca AS pedidovenda_cfop_codigo_fk,
    ped.pedmodcob AS pedidovenda_modcobranca_codigo_fk,
    ped.descricao_status_pedido_venda AS pedidovenda_status,
    ped.descricao_situacao_pedido_venda AS pedidovenda_situacao,
    ped.pedtppvco AS pedidovenda_tabelavenda_codigo_fk,
    ped.vendedor AS pedidovenda_vendedor_codigo_fk,
    ped.peddata AS pedidovenda_data_emissao,
    ped.pedfatur AS pedidovenda_data_producao,
    ped.pedprevi AS pedidovenda_data_previsao,
    ped.pedcliente AS pedidovenda_empresa_codigo_fk,
    ped.pedcondica AS pedidovenda_condicao_pagto_codigo_fk,
    ped.pedordcomp AS pedidovenda_numero_ordem_compra,
    ped.pedocemis AS pedidovenda_data_ordem_compra,
    ped.pedordcmp AS pedidovenda_pedido_representante,
    ped.lcapecod AS pedidovenda_lotecarga_codigo_fk,
    ped.lcaseque AS pedidovenda_lotecarga_sequencia,
    ped.pedentcid AS pedidovenda_cidade_entrega_codigo_fk,
    ped.pedtransp AS pedidovenda_transportadora_codigo_fk,
    ped.pedredesp AS pedidovenda_redespacho_codigo_fk,
    pp.pprseq AS pedidovenda_produto_sequencia,
    pp.pprproduto AS pedidovenda_produto_codigo_fk,
    pp.pprquanti AS pedidovenda_qtde_produto,
    round((select prod.proqtdger from produto prod where prod.produto = pp.pprproduto) * pp.pprquanti, 4) AS pedidovenda_qtde_gerencial_produto,
    round((select prod.proliqui from produto prod where prod.produto = pp.pprproduto) * pp.pprquanti, 4) AS pedidovenda_qtde_peso_liquido_produto,
    pp.pprvlsoma - (pp.ppricmfic + pp.pprdesfic) + pp.pprvlipi + pp.ppripifrv + pp.pprvlfrete + pp.pprfreval + pp.pprdespesa + pp.pprvlrsub + pp.pprsubfrv + COALESCE(NULLIF(stpis.pstpvlrpis, 0::numeric), NULLIF(stpis.pstpvlr2pi, 0::numeric), 0::numeric) + COALESCE(NULLIF(stpis.pstpvlrcof, 0::numeric), NULLIF(stpis.pstpvlr2co, 0::numeric), 0::numeric) - COALESCE(pdesc.vlr_desconto, 0::numeric) AS pedidovenda_valor_produto_total,
    pp.pprvalor AS pedidovenda_valor_produto_unitario,
    pp.pprvlipi AS pedidovenda_valor_produto_ipi,
    pp.pprvlfrete + pp.pprfreval AS pedidovenda_valor_produto_frete,
    COALESCE(pdesc.vlr_desconto, 0::numeric) AS pedidovenda_valor_produto_desconto,
    pp.pprvlrsub + pp.pprsubfrv AS pedidovenda_valor_produto_subst_tributaria,
    pp.pprdespesa AS pedidovenda_valor_produto_despesa,
    pp.pprvlsoma AS pedidovenda_valor_produto_subtotal,
    COALESCE(pp.pprqtdaten, 0::numeric) AS pedidovenda_qtde_atendida_produto,
    COALESCE(pp.pprquanti, 0::numeric) - COALESCE(pp.pprqtdaten, 0::numeric) AS pedidovenda_qtde_saldo_produto,
        CASE
            WHEN (( SELECT count(*) AS count
               FROM acaorde3
              WHERE ped.pedido = acaorde3.acaorped AND pp.pprseq = acaorde3.acaorseq)) > 0 THEN 'S'::text
            ELSE 'N'::text
        END AS pedidovenda_com_ordem_fabricacao,
    pp.pprordco AS pedidovenda_numero_ordem_compra_produto,
    pp.pprocprev AS pedidovenda_data_ordem_compra_produto,
    btrim(pp.pprtabpre::text || '-'::text) || btrim(pp.pprproduto::text) AS pedidovenda_tabela_preco_item_codigo_fk,
    COALESCE(pp.pprdtatend, '0001-01-01'::date) AS pedidovenda_data_atendimento,
    pp.pproperaca AS pedidovenda_cfopitem_codigo_fk,
    pp.pprprevi AS pedidovenda_data_previsao_item,
    pp.pprvlicms AS pedidovenda_valor_icms_item,
    COALESCE(NULLIF(stpis.pstpvlrpis, 0::numeric), NULLIF(stpis.pstpvlr2pi, 0::numeric), 0::numeric) AS pedidovenda_valor_pis_st_item,
    COALESCE(NULLIF(stpis.pstpvlrcof, 0::numeric), NULLIF(stpis.pstpvlr2co, 0::numeric), 0::numeric) AS pedidovenda_valor_cofins_st_item,
    ped.pedobserva as pedidovenda_observacao_1,
    ped.pedobserv2 as pedidovenda_observacao_2
   FROM pedprodu pp
     LEFT JOIN ( SELECT pd.pddpedido,
            pd.pddsequen,
            COALESCE(pd.pddvlrprod, 0::numeric) + COALESCE(pd.pddprcprod, 0::numeric) + COALESCE(pd.pddvlripi, 0::numeric) + COALESCE(pd.pddprcfret, 0::numeric) + COALESCE(pd.pddvldesp, 0::numeric) + COALESCE(pd.pddvlrfret, 0::numeric) + COALESCE(pd.pddprdesp, 0::numeric) + COALESCE(pd.pddprcipi, 0::numeric) AS vlr_desconto
           FROM peddesco pd) pdesc ON pdesc.pddpedido = pp.pedido AND pdesc.pddsequen = pp.pprseq
     LEFT JOIN ( SELECT pedido.pedido,
            pedido.deposito,
                CASE
                    WHEN pedido.pedsitua = 'A'::bpchar THEN 'Atendido Total'::text
                    WHEN pedido.pedsitua = 'P'::bpchar THEN 'Atendido Parcial'::text
                    WHEN pedido.pedsitua = 'I'::bpchar THEN 'O.C. por Item'::text
                    ELSE 'Pedido em Aberto'::text
                END AS descricao_status_pedido_venda,
                CASE
                    WHEN pedido.pedaprova = 'N'::bpchar THEN 'Nao Aprovado'::text
                    WHEN pedido.pedaprova = 'C'::bpchar THEN 'Cancelado'::text
                    WHEN pedido.pedcabsta <> 'S'::bpchar THEN 'Incompleto'::text
                    ELSE 'Aprovado'::text
                END AS descricao_situacao_pedido_venda,
            pedido.tipoped,
            pedido.pedoperaca,
            pedido.peddata,
            pedido.pedfatur,
            pedido.pedprevi,
            pedido.pedcondica,
            pedido.pedcliente,
            pedido.pedregca,
            pedido.pedmodcob,
            pedido.pedtppvco,
            pedido.pedordcomp,
            pedido.pedocemis,
            pedido.pedordcmp,
            ven.vendedor,
            pedido.lcapecod,
            pedido.lcaseque,
			pedido.pedentcid,
			pedido.pedobserva,
			pedido.pedobserv2,
            pedido.pedtransp,
			pedido.pedredesp  
           FROM pedido
             LEFT JOIN ( SELECT DISTINCT ON (ve.coppedido) ve.coppedido,
                    ve.vendedor
                   FROM comiped ve
                  ORDER BY ve.coppedido, ve.copseq) ven ON ven.coppedido = pedido.pedido) ped ON pp.pedido = ped.pedido
     LEFT JOIN pedstpis stpis ON stpis.pstppedido = pp.pedido AND stpis.pstpsequen = pp.pprseq

ALTER TABLE pw_pedido_venda
  OWNER TO postgres;
