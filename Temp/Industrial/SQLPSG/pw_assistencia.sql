-- View: pw_assistencia

-- DROP VIEW pw_assistencia;

CREATE OR REPLACE VIEW pw_assistencia AS 
 SELECT a.assistec AS assistencia_codigo_pk,
    a.assdeposit AS assistencia_deposito_codigo_fk,
    a.asscliente AS assistencia_empresa_codigo_fk,
    a.assoperaca AS assistencia_cfop_codigo_fk,
    a.asstabpre AS assistencia_tabelavenda_codigo_fk,
    a.assmodcob AS assistencia_modcobranca_codigo_fk,
    a.assconpag AS assistencia_condicao_pagto_codigo_fk,
    a.assdata AS assistencia_data_emissao,
    a.assdteprod AS assistencia_data_producao,
    a.assdtaent AS assistencia_data_previsao,
    a.assendent AS assistencia_endereco_entrega,
    a.asscident AS assistencia_cidade_entrega_codigo_fk,
    a.asscepent AS assistencia_cep_endereco_entrega,
    a.asscomp AS assistencia_complemento,
    a1.assdtatend AS assistencia_data_atendimento,
        CASE
            WHEN a.assstatus = 'PT'::bpchar THEN 'Pendente Total'::text
            WHEN a.assstatus = 'AP'::bpchar THEN 'Atendido Parcial'::text
            WHEN a.assstatus = 'AT'::bpchar THEN 'Atendido Total'::text
            ELSE NULL::text
        END AS assistencia_status,
        CASE
            WHEN par.aspmarep = 'S'::bpchar THEN comi.comiarec
            ELSE a.assrepres::bigint
        END AS assistencia_vendedor_codigo_fk,
    a1.aspseq AS assistencia_produto_sequencia,
    a1.aspproduto AS assistencia_produto_codigo_fk,
    a1.aspprodref AS assistencia_produto_referencia_codigo,
    produto2.pronome AS assistencia_produto_referencia_descricao,
    a1.aspquanti AS assistencia_qtde_produto,
    round(prod.proliqui * a1.aspquanti, 4) AS assistencia_qtde_peso_liquido_produto,
    a1.aspvalor AS assistencia_valor_produto_unitario,
    a1.aspvlripi AS assistencia_valor_produto_ipi,
    a1.aspvlrfre AS assistencia_valor_produto_frete,
    a1.aspvlrsub AS assistencia_valor_produto_subst_tributaria,
    0 AS assistencia_valor_produto_despesa,
    a1.assqdtaten AS assistencia_qtde_atendida_produto,
    a1.assacao AS assistencia_acao_assistencia_codigo_fk,
    a1.aspmotivo AS assistencia_motivo_assistencia_codigo_fk,
        CASE
            WHEN a.asssitua = 'AP'::bpchar THEN 'Aprovada'::text
            WHEN a.asssitua = 'NA'::bpchar THEN 'Não Aprovada'::text
            WHEN a.asssitua = 'CA'::bpchar THEN 'Cancelada'::text
            ELSE 'Aprovada'::text
        END AS assistencia_situacao,
    a.astecnico AS assistencia_assistente_tecnico_codigo_fk,
    a.asstipo AS assistencia_tipo_assistencia_codigo_fk,
    ( SELECT hiscusto.hicuvlrcu
           FROM hiscusto
          WHERE hiscusto.hicuproco = a1.aspproduto AND (hiscusto.hicudepo = a.assdeposit OR hiscusto.hicudepo = 0) AND hiscusto.hicudatal <= a.assdata
          ORDER BY hiscusto.hicudatal DESC, hiscusto.hicuhoral DESC
         LIMIT 1) AS assistencia_valor_produto_custorep_emissao,
    ( SELECT hiscusto.hicuvlrcu
           FROM hiscusto
          WHERE hiscusto.hicuproco = a1.aspproduto AND (hiscusto.hicudepo = a.assdeposit OR hiscusto.hicudepo = 0) AND (hiscusto.hicudatal < 'now'::text::date OR hiscusto.hicudatal = 'now'::text::date AND hiscusto.hicuhoral < 'now'::text::time with time zone::character(8))
          ORDER BY hiscusto.hicudatal DESC, hiscusto.hicuhoral DESC
         LIMIT 1) AS assistencia_valor_produto_custorep_atual,
    round(a1.aspquanti * a1.aspvalor, 2) AS assistencia_valor_produto_total
   FROM assistec a,
    assparam par,
    assiste1 a1
     LEFT JOIN ( SELECT DISTINCT ON (c.comiass) c.comiass,
            c.comiarec
           FROM comiass c) comi ON a1.assistec = comi.comiass
     LEFT JOIN ( SELECT p.produto,
            p.proliqui
           FROM produto p) prod ON a1.aspproduto = prod.produto
     LEFT JOIN ( SELECT p2.produto,
            p2.pronome
           FROM produto p2) produto2 ON a1.aspprodref = produto2.produto
  WHERE a.assistec = a1.assistec AND par.asprmass = 1;

ALTER TABLE pw_assistencia
  OWNER TO postgres;

