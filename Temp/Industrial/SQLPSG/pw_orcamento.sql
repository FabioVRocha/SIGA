-- View: pw_orcamento

-- DROP VIEW pw_orcamento;

CREATE OR REPLACE VIEW pw_orcamento AS 
 SELECT o.orcacod AS orcamento_codigo_pk,
    'Padrão'::text AS orcamento_formato,
    o.orcatipo AS orcamento_tipo_orcamento_codigo_fk,
    0 AS orcamento_codigo_interno,
    0 AS orcamento_versao,
    o.orcadep AS orcamento_deposito_codigo_fk,
    '-'::text AS orcamento_regiao_custo_fk,
    o.orcacfop AS orcamento_cfop_codigo_fk,
    o.orcamodcob AS orcamento_modcobranca_codigo_fk,
        CASE
            WHEN o.orcastatus = 'A'::bpchar THEN 'Atendido Total'::text
            WHEN o.orcastatus = 'P'::bpchar THEN 'Atendido Parcial'::text
            WHEN o.orcastatus = 'D'::bpchar THEN 'Orçamento Perdido'::text
            WHEN o.orcastatus = ' '::bpchar THEN 'Orçamento Pendente'::text
            ELSE NULL::text
        END AS orcamento_status,
    o.orcatabv AS orcamento_tabelavenda_codigo_fk,
        CASE
            WHEN par.ocprepres = 'S'::bpchar THEN comi.comirepc
            ELSE o.orcarep
        END AS orcamento_vendedor_codigo_fk,
    o.orcadta AS orcamento_data_emissao,
    o.orcaprev AS orcamento_data_previsao,
    o.orcavalida AS orcamento_data_validade,
    o.orcaemp AS orcamento_empresa_codigo_fk,
    o.orcacond AS orcamento_condicao_pagto_codigo_fk,
    o1.orcpseq AS orcamento_produto_sequencia,
    o1.orcpprod AS orcamento_produto_codigo_fk,
    o1.orcpqtde AS orcamento_qtde_produto,
    round(prod.proliqui * o1.orcpqtde, 4) AS orcamento_qtde_peso_liquido_produto,
        CASE
            WHEN o.orcadescv > 0::numeric THEN round(COALESCE(o1.orcpvlrtot - o1.orcpvlrtot / NULLIF(o.orcvlfin + o.orcadescv, 0::numeric) * o.orcadescv, 0::numeric), 2)
            ELSE o1.orcpvlrtot
        END AS orcamento_valor_produto_total,
    o1.orcpvalor AS orcamento_valor_produto_unitario,
    o1.orcpvlripi AS orcamento_valor_produto_ipi,
    o1.orcpvlrfre + o1.orcpfrval AS orcamento_valor_produto_frete,
    o1.orcpvlbase AS orcamento_valor_produto_subst_tributaria,
    o1.orcpdespes AS orcamento_valor_produto_despesa,
    o1.orcpdsaldo AS orcamento_qtde_atendida_produto,
    o1.orcpqtde - o1.orcpdsaldo AS orcamento_qtde_saldo_produto
   FROM orcament o,
    ocmparam par,
    orcamen1 o1
     LEFT JOIN ( SELECT DISTINCT ON (c.comiorc) c.comiorc,
            c.comirepc
           FROM comiorc c) comi ON o1.orcacod = comi.comiorc
     LEFT JOIN ( SELECT p.produto,
            p.proliqui
           FROM produto p) prod ON o1.orcpprod = prod.produto
  WHERE o.orcacod = o1.orcacod AND par.ocpid = 1
UNION ALL
 SELECT DISTINCT e.orenum AS orcamento_codigo_pk,
    'Vários'::text AS orcamento_formato,
    e.oretipo AS orcamento_tipo_orcamento_codigo_fk,
    e.orecod AS orcamento_codigo_interno,
    e.orever AS orcamento_versao,
    e.oredepo AS orcamento_deposito_codigo_fk,
    e.oreregiao AS orcamento_regiao_custo_fk,
    e.oreopera AS orcamento_cfop_codigo_fk,
    e.oremodco AS orcamento_modcobranca_codigo_fk,
        CASE
            WHEN e.orestat = 'A'::bpchar THEN 'Atendido Total'::text
            WHEN e.orestat = 'P'::bpchar THEN 'Atendido Parcial'::text
            WHEN e.orestat = 'C'::bpchar THEN 'Orçamento Cancelado'::text
            WHEN e.orestat = ' '::bpchar THEN 'Orçamento Pendente'::text
            ELSE NULL::text
        END AS orcamento_status,
    e.oretabpv AS orcamento_tabelavenda_codigo_fk,
        CASE
            WHEN par.ocprepes = 'S'::bpchar THEN comi.corerep
            ELSE e.orerepr
        END AS orcamento_vendedor_codigo_fk,
    e.oredtin AS orcamento_data_emissao,
    e.oredtpre AS orcamento_data_previsao,
    e.orevali AS orcamento_data_validade,
    e.oreclie AS orcamento_empresa_codigo_fk,
    e.orecond AS orcamento_condicao_pagto_codigo_fk,
    e1.orepseq AS orcamento_produto_sequencia,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN e1.oreppro
            ELSE ore.orepfil
        END AS orcamento_produto_codigo_fk,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN e1.orepqtd
            ELSE ore.orepqtde
        END AS orcamento_qtde_produto,
        CASE
            WHEN e1.orestniv = 9 THEN round(pro.proliqui * e1.orepqtd, 4)
            ELSE 0.0000
        END AS orcamento_qtde_peso_liquido_produto,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN
            CASE
                WHEN e.oredesvl > 0::numeric THEN round(COALESCE(e1.orepvlt - e1.orepvlt / NULLIF(e.orevlfin + e.oredesvl, 0::numeric) * e.oredesvl, 0::numeric), 2)
                ELSE e1.orepvlt
            END
            ELSE
            CASE
                WHEN e.oredesvl > 0::numeric THEN round(COALESCE(ore.oreppvlt - ore.oreppvlt / NULLIF(e.orevlfin + e.oredesvl, 0::numeric) * e.oredesvl, 0::numeric), 2)
                ELSE ore.oreppvlt
            END
        END AS orcamento_valor_produto_total,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN e1.orepvlu
            ELSE ore.oreppvlu
        END AS orcamento_valor_produto_unitario,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN e1.orepvlipi
            ELSE ore.oreppvlipi
        END AS orcamento_valor_produto_ipi,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN e1.orepvlfre + e1.orepfrval
            ELSE ore.oreppvlfre + ore.oreppfrval
        END AS orcamento_valor_produto_frete,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN e1.orepvlsba
            ELSE ore.oreppvlsub
        END AS orcamento_valor_produto_subst_tributaria,
    0.0000 AS orcamento_valor_produto_despesa,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN e1.orepsald
            ELSE ore.oreppsld
        END AS orcamento_qtde_atendida_produto,
        CASE
            WHEN e1.orestniv = 9 OR e1.orestniv = 0 THEN e1.orepqtd - e1.orepsald
            ELSE round(ore.orepqtde * e1.orepqtd - ore.oreppsld, 4)
        END AS orcamento_qtde_saldo_produto
   FROM orcaesp e,
    ocmparam par,
    orcaesp6 e1
     LEFT JOIN ( SELECT DISTINCT ON (c.corecod) c.corecod,
            c.corerep
           FROM comiores c) comi ON e1.orecod = comi.corecod
     LEFT JOIN ( SELECT p.produto,
            p.proliqui
           FROM produto p) pro ON e1.oreppro = pro.produto
     LEFT JOIN ( SELECT o.orecod,
            o.orepseq,
            o.oreppai,
            o.orepfil,
            o.oreppvlt,
            o.orepqtde,
            o.oreppvlu,
            o.oreppvlipi,
            o.oreppvlfre,
            o.oreppfrval,
            o.oreppvlsub,
            o.oreppsld
           FROM orestrut o) ore ON e1.orecod = ore.orecod AND e1.orepseq = ore.orepseq AND e1.oreppro = ore.oreppai
  WHERE e.orecod = e1.orecod AND e.oreati = 'S'::bpchar AND par.ocpid = 1
UNION ALL
 SELECT e1.ocmid AS orcamento_codigo_pk,
    'Um'::text AS orcamento_formato,
    '-'::character(3) AS orcamento_tipo_orcamento_codigo_fk,
    0 AS orcamento_codigo_interno,
    0 AS orcamento_versao,
    0 AS orcamento_deposito_codigo_fk,
    e1.ocmregcod AS orcamento_regiao_custo_fk,
    '-'::character(10) AS orcamento_cfop_codigo_fk,
    '-'::character(2) AS orcamento_modcobranca_codigo_fk,
        CASE
            WHEN e1.ocmstatus = 'N'::bpchar OR e1.ocmstatus = ''::bpchar THEN 'Não Atendido'::text
            WHEN e1.ocmstatus = 'A'::bpchar THEN 'Atendido'::text
            WHEN e1.ocmstatus = 'P'::bpchar THEN 'Parcial'::text
            ELSE NULL::text
        END AS orcamento_status,
    '-'::character(3) AS orcamento_tabelavenda_codigo_fk,
    0 AS orcamento_vendedor_codigo_fk,
    e1.ocmdtinc AS orcamento_data_emissao,
    '0001-01-01'::date AS orcamento_data_previsao,
    e1.ocmdtval AS orcamento_data_validade,
    e1.ocmempid AS orcamento_empresa_codigo_fk,
    e1.ocmconid AS orcamento_condicao_pagto_codigo_fk,
    1 AS orcamento_produto_sequencia,
    e1.ocmproid AS orcamento_produto_codigo_fk,
    e1.ocmquanti AS orcamento_qtde_produto,
    round(prod.proliqui * e1.ocmquanti::numeric, 4) AS orcamento_qtde_peso_liquido_produto,
    e1.ocmvlrtot + e1.ocmprjvlr AS orcamento_valor_produto_total,
        CASE
            WHEN e1.ocmquanti = 0 THEN e1.ocmvlrtot + e1.ocmprjvlr
            ELSE round((e1.ocmvlrtot + e1.ocmprjvlr) / e1.ocmquanti::numeric, 2)
        END AS orcamento_valor_produto_unitario,
    0 AS orcamento_valor_produto_ipi,
    0 AS orcamento_valor_produto_frete,
    0 AS orcamento_valor_produto_subst_tributaria,
    0 AS orcamento_valor_produto_despesa,
        CASE
            WHEN e1.ocmpedido = 0 THEN 0
            ELSE e1.ocmquanti
        END AS orcamento_qtde_atendida_produto,
        CASE
            WHEN e1.ocmpedido = 0 THEN e1.ocmquanti
            ELSE 0
        END AS orcamento_qtde_saldo_produto
   FROM ocmento e1
     LEFT JOIN ( SELECT p.produto,
            p.proliqui
           FROM produto p) prod ON e1.ocmproid = prod.produto;

ALTER TABLE pw_orcamento
  OWNER TO postgres;
