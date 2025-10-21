-- View: pw_faturamento

-- DROP VIEW pw_faturamento;

CREATE OR REPLACE VIEW pw_faturamento AS 
 SELECT doc.datadoc AS faturamento_data_faturamento,
    doc.notdocto AS faturamento_nf_numero,
    doc.notserie AS faturamento_nf_serie,
    ven1.comnvende AS faturamento_vendedor_codigo_fk,
    doc.notclifor AS faturamento_empresa_codigo_fk,
    t.priproduto AS faturamento_produto_codigo_fk,
    t.prideposit AS faturamento_deposito_codigo_fk,
    doc.notcondica AS faturamento_condicaopagto_codigo_fk,
    doc.operacao AS faturamento_cfop_codigo_fk,
    t.operacao AS faturamento_cfopitem_codigo_fk,
    mob.mobdescri AS faturamento_mao_obra,
    sum(t.priquanti) AS faturamento_qtde_produto,
    round(sum(pro.proqtdger * t.priquanti), 4) AS faturamento_qtde_gerencial_produto,
    round(sum(pro.proliqui * t.priquanti), 4) AS faturamento_qtde_peso_liquido_produto,
    sum(t.privltotal + t.privlipi + t.privlfrete - t.privldecon + t.privlsubst + t.privldesp * 1::numeric - t.pridescof - t.pridespis) AS faturamento_valor_total,
    sum(t.privlipi) AS faturamento_valor_ipi,
    sum(t.privlfrete) AS faturamento_valor_frete,
    sum(t.privldecon) AS faturamento_valor_desconto,
    sum(t.privlsubst) AS faturamento_valor_subst_tributaria,
    sum(t.privldesp) AS faturamento_valor_despesa,
    sum(t.pridescof) AS faturamento_valor_desc_cofins,
    sum(t.pridespis) AS faturamento_valor_desc_pis,
    sum(
        CASE
            WHEN dad.dadmulemp = 'S'::bpchar THEN round(GREATEST(cus.ccrcus, 0::numeric) * t.priquanti, 2)
            ELSE round(GREATEST(pro.procusrep, 0::numeric) * t.priquanti, 2)
        END) AS faturamento_valor_custo_reposicao,
    lcn.lcncidade AS faturamento_cidade_entrega_codigo_fk,
    lcn.lcncep AS faturamento_entrega_cep,
    lcn.lcnrua AS faturamento_entrega_rua,
    lcn.lcncomp AS faturamento_entrega_complemento,
    doc.controle AS faturamento_controle,
    doc.notcodac AS faturamento_chave_acesso,
        CASE
            WHEN doc.nostiptra::text = 1::text THEN 'EXW'::text
            WHEN doc.nostiptra::text = 2::text THEN 'C+F'::text
            WHEN doc.nostiptra::text = 3::text THEN 'FOB'::text
            WHEN doc.nostiptra::text = 4::text THEN 'CIF'::text
            WHEN doc.nostiptra::text = 5::text THEN 'FAS'::text
            WHEN doc.nostiptra::text = 6::text THEN 'Terceiros'::text
            WHEN doc.nostiptra::text = 7::text THEN 'FCA'::text
            WHEN doc.nostiptra::text = 8::text THEN 'CPT'::text
            WHEN doc.nostiptra::text = 9::text THEN 'CFR'::text
            ELSE 'Sem Tipo de Frete'::text
        END AS faturamento_tipo_frete,
    t.prialqicms AS faturamento_aliquota_icms,
    t.pribasicms AS faturamento_base_icms,
    t.privlicms AS faturamento_valor_icms,
    t.pritripis AS faturamento_cst_pis,
    t.prialpis AS faturamento_aliquota_pis,
    t.privlpis AS faturamento_valor_pis,
    t.pritricof AS faturamento_cst_cofins,
    t.prialcof AS faturamento_aliquota_cofins,
    t.privlcof AS faturamento_valor_cofins,
    t.pribaseipi AS faturamento_base_ipi,
    t.prialqipi AS faturamento_aliquota_ipi,
    t.pribaspis AS faturamento_base_cofins,
    t.pribaspis AS faturamento_base_pis,
    t.priredpisc AS faturamento_valor_reducao_icms_base_pis_cofins,
    btrim(t.pritabpre::text || '-'::text) || btrim(t.priproduto::text) AS faturamento_tabela_preco_item_codigo_fk,
    t.pritabpre AS faturamento_tabela_venda_codigo_fk,
    ddt.ddtdtcol AS faturamento_data_coleta,
    doc.nostransp AS faturamento_transportadora_codigo_fk,
    doc.nostredesp AS faturamento_redespacho_codigo_fk,
    doc.nosplaca AS faturamento_placa
   FROM toqmovi t
     LEFT JOIN ( SELECT o.operacao,
            o.opeapv,
            o.opevlcom
           FROM opera o) opi ON opi.operacao = t.operacao
     LEFT JOIN ( SELECT p.produto,
            p.proqtdger,
            p.proliqui,
            p.procusrep
           FROM produto p) pro ON pro.produto = t.priproduto
     LEFT JOIN ( SELECT c.ccrpro,
            c.ccrdep,
            c.ccrcus
           FROM prodcust c) cus ON cus.ccrpro = t.priproduto AND cus.ccrdep = t.prideposit
     LEFT JOIN ( SELECT d.controle,
                CASE
                    WHEN d.notentrada <> '0001-01-01'::date AND d.notentrada IS NOT NULL THEN d.notentrada
                    ELSE d.notdata
                END AS datadoc,
            d.operacao,
            d.notserie,
            d.notdocto,
            d.notclifor,
            d.notcondica,
            d.notdtdigit,
            d.notobsfisc,
            d.notcodac,
            d.nostiptra,
            d.nostransp,
		    d.nostredesp,
		    d.nosplaca
           FROM doctos d) doc ON doc.controle = t.itecontrol
     JOIN ( SELECT o.operacao,
            o.opetransac
           FROM opera o) opd ON opd.operacao = doc.operacao AND opd.operacao > '4'::bpchar
     LEFT JOIN ( SELECT DISTINCT ON (c.comncontr) c.comncontr,
            c.comnvende,
            v.vennome
           FROM comnf c,
            vendedor v
          WHERE v.vendedor = c.comnvende AND v.ventiprel = 'R'::bpchar
          ORDER BY c.comncontr, c.comnseq) ven1 ON ven1.comncontr = doc.controle
     LEFT JOIN ( SELECT d.dadempresa,
            d.dadmulemp
           FROM dadosemp d) dad ON dad.dadempresa = 1
     LEFT JOIN ( SELECT m.mobcontrol,
            m.mobdescri,
            m.mobsequen
           FROM mobdesc m) mob ON mob.mobcontrol = t.itecontrol::numeric AND mob.mobsequen = t.prisequen
     LEFT JOIN ( SELECT ncl.lcncontr,
            ncl.lcnrua,
            ncl.lcncep,
            ncl.lcnestado,
            ncl.lcncomp,
            ncl.lcncidade
           FROM lcnota ncl) lcn ON lcn.lcncontr = doc.controle
     LEFT JOIN docdtcol ddt ON ddt.ddtcontro = doc.controle
  WHERE t.prisequen < 500 AND doc.notdocto IS NOT NULL AND doc.notdocto <> ''::bpchar AND doc.notdtdigit IS NOT NULL AND doc.notdtdigit <> '0001-01-01'::date AND substr(doc.notobsfisc::text, 1, 10) <> 'NF ANULADA'::text AND opi.opeapv = 'S'::bpchar AND opi.opevlcom = 'S'::bpchar
  GROUP BY doc.datadoc, ven1.comnvende, ven1.vennome, doc.notdocto, doc.notserie, doc.notclifor, t.priproduto, t.prideposit, doc.notcondica, doc.operacao, mob.mobdescri, lcn.lcncidade, 
  lcn.lcncep, lcn.lcnrua, lcn.lcncomp, doc.controle, doc.notcodac, doc.nostiptra, t.prialqicms, t.pribasicms, t.privlicms, t.prialpis, t.privlpis, t.prialcof, 
  t.privlcof, t.pribaseipi, t.prialqipi, t.pribaspis, t.pritabpre, t.operacao, ddt.ddtdtcol, doc.nostransp, doc.nostredesp, doc.nosplaca,
  t.pritripis, t.pritricof, t.priredpisc
UNION ALL
 SELECT doc.datadoc AS faturamento_data_faturamento,
    doc.notdocto AS faturamento_nf_numero,
    doc.notserie AS faturamento_nf_serie,
    dvv.ven1 AS faturamento_vendedor_codigo_fk,
    doc.notclifor AS faturamento_empresa_codigo_fk,
    t.priproduto AS faturamento_produto_codigo_fk,
    t.prideposit AS faturamento_deposito_codigo_fk,
    doc.notcondica AS faturamento_condicaopagto_codigo_fk,
    doc.operacao AS faturamento_cfop_codigo_fk,
    t.operacao AS faturamento_cfopitem_codigo_fk,
    mob.mobdescri AS faturamento_mao_obra,
    sum(t.priquanti) * (-1)::numeric AS faturamento_qtde_produto,
    round(sum(pro.proqtdger * t.priquanti), 4) * (-1)::numeric AS faturamento_qtde_gerencial_produto,
    round(sum(pro.proliqui * t.priquanti), 4) * (-1)::numeric AS faturamento_qtde_peso_liquido_produto,
    sum(t.privltotal + t.privlipi + t.privlfrete - t.privldecon + t.privlsubst + t.privldesp * 1::numeric - t.pridescof - t.pridespis) * (-1)::numeric AS faturamento_valor_total,
    sum(t.privlipi) * (-1)::numeric AS faturamento_valor_ipi,
    sum(t.privlfrete) * (-1)::numeric AS faturamento_valor_frete,
    sum(t.privldecon) * (-1)::numeric AS faturamento_valor_desconto,
    sum(t.privlsubst) * (-1)::numeric AS faturamento_valor_subst_tributaria,
    sum(t.privldesp) * (-1)::numeric AS faturamento_valor_despesa,
    sum(t.pridescof) * (-1)::numeric AS faturamento_valor_desc_cofins,
    sum(t.pridespis) * (-1)::numeric AS faturamento_valor_desc_pis,
    sum(
        CASE
            WHEN dad.dadmulemp = 'S'::bpchar THEN round(GREATEST(cus.ccrcus, 0::numeric) * t.priquanti, 2) * (-1)::numeric
            ELSE round(GREATEST(pro.procusrep, 0::numeric) * t.priquanti, 2) * (-1)::numeric
        END) AS faturamento_valor_custo_reposicao,
    lcn.lcncidade AS faturamento_cidade_entrega_codigo_fk,
    lcn.lcncep AS faturamento_entrega_cep,
    lcn.lcnrua AS faturamento_entrega_rua,
    lcn.lcncomp AS faturamento_entrega_complemento,
    doc.controle AS faturamento_controle,
    doc.notcodac AS faturamento_chave_acesso,
        CASE
            WHEN doc.nostiptra::text = 1::text THEN 'EXW'::text
            WHEN doc.nostiptra::text = 2::text THEN 'C+F'::text
            WHEN doc.nostiptra::text = 3::text THEN 'FOB'::text
            WHEN doc.nostiptra::text = 4::text THEN 'CIF'::text
            WHEN doc.nostiptra::text = 5::text THEN 'FAS'::text
            WHEN doc.nostiptra::text = 6::text THEN 'Terceiros'::text
            WHEN doc.nostiptra::text = 7::text THEN 'FCA'::text
            WHEN doc.nostiptra::text = 8::text THEN 'CPT'::text
            WHEN doc.nostiptra::text = 9::text THEN 'CFR'::text
            ELSE 'Sem Tipo de Frete'::text
        END AS faturamento_tipo_frete,
    t.prialqicms AS faturamento_aliquota_icms,
    t.pribasicms AS faturamento_base_icms,
    t.privlicms * (-1)::numeric AS faturamento_valor_icms,
    t.pritripis AS faturamento_cst_pis,
    t.prialpis AS faturamento_aliquota_pis,
    t.privlpis * (-1)::numeric AS faturamento_valor_pis,
    t.pritricof AS faturamento_cst_cofins,
    t.prialcof AS faturamento_aliquota_cofins,
    t.privlcof * (-1)::numeric AS faturamento_valor_cofins,
    t.pribaseipi AS faturamento_base_ipi,
    t.prialqipi AS faturamento_aliquota_ipi,
    t.pribaspis AS faturamento_base_cofins,
    t.pribaspis AS faturamento_base_pis,
    t.priredpisc AS faturamento_valor_reducao_icms_base_pis_cofins,
    btrim(t.pritabpre::text || '-'::text) || btrim(t.priproduto::text) AS faturamento_tabela_preco_item_codigo_fk,
    t.pritabpre AS faturamento_tabela_venda_codigo_fk,
    ddt.ddtdtcol AS faturamento_data_coleta,
    doc.nostransp AS faturamento_transportadora_codigo_fk,
    doc.nostredesp AS faturamento_redespacho_codigo_fk,
    doc.nosplaca AS faturamento_placa
   FROM toqmovi t
     LEFT JOIN ( SELECT o.operacao,
            o.opeapv,
            o.opevlcom
           FROM opera o) opi ON opi.operacao = t.operacao
     LEFT JOIN ( SELECT p.produto,
            p.proqtdger,
            p.proliqui,
            p.procusrep
           FROM produto p) pro ON pro.produto = t.priproduto
     LEFT JOIN ( SELECT c.ccrpro,
            c.ccrdep,
            c.ccrcus
           FROM prodcust c) cus ON cus.ccrpro = t.priproduto AND cus.ccrdep = t.prideposit
     LEFT JOIN ( SELECT v.dvvcontrol,
            v.dvvsequen,
            v.dvvcontrsa,
            com1.comnvende AS ven1,
            com1.vennome
           FROM devvenda v
             LEFT JOIN ( SELECT DISTINCT ON (c.comncontr) c.comncontr,
                    c.comnvende,
                    n.vennome
                   FROM comnf c,
                    vendedor n
                  WHERE n.vendedor = c.comnvende AND n.ventiprel = 'R'::bpchar
                  ORDER BY c.comncontr) com1 ON com1.comncontr::numeric = v.dvvcontrsa::numeric) dvv ON dvv.dvvcontrol::numeric = t.itecontrol::numeric AND dvv.dvvsequen = t.prisequen
     LEFT JOIN ( SELECT d.controle,
                CASE
                    WHEN d.notentrada <> '0001-01-01'::date AND d.notentrada IS NOT NULL THEN d.notentrada
                    ELSE d.notdata
                END AS datadoc,
            d.operacao,
            d.notserie,
            d.notdocto,
            d.notclifor,
            d.notcondica,
            d.notdtdigit,
            d.notobsfisc,
            d.notcodac,
            d.nostiptra,
            d.nostransp,
		    d.nostredesp,
		    d.nosplaca
           FROM doctos d) doc ON doc.controle = t.itecontrol
     JOIN ( SELECT o.operacao,
            o.opetransac
           FROM opera o) opd ON opd.operacao = doc.operacao AND doc.operacao < '4'::bpchar AND opd.opetransac = 2
     LEFT JOIN ( SELECT d.dadempresa,
            d.dadmulemp
           FROM dadosemp d) dad ON dad.dadempresa = 1
     LEFT JOIN ( SELECT m.mobcontrol,
            m.mobdescri,
            m.mobsequen
           FROM mobdesc m) mob ON mob.mobcontrol = t.itecontrol::numeric AND mob.mobsequen = t.prisequen
     LEFT JOIN ( SELECT ncl.lcncontr,
            ncl.lcnrua,
            ncl.lcncep,
            ncl.lcnestado,
            ncl.lcncomp,
            ncl.lcncidade
           FROM lcnota ncl) lcn ON lcn.lcncontr = doc.controle
     LEFT JOIN docdtcol ddt ON ddt.ddtcontro = doc.controle
  WHERE t.prisequen < 500 AND doc.notdocto IS NOT NULL AND doc.notdocto <> ''::bpchar AND doc.notdtdigit IS NOT NULL AND doc.notdtdigit <> '0001-01-01'::date AND substr(doc.notobsfisc::text, 1, 10) <> 'NF ANULADA'::text AND (opi.opeapv = 'S'::bpchar AND opi.opevlcom = 'S'::bpchar OR t.pritransac = 2)
  GROUP BY doc.datadoc, dvv.ven1, dvv.vennome, doc.notdocto, doc.notserie, doc.notclifor, t.priproduto, t.prideposit, doc.notcondica, doc.operacao, mob.mobdescri, lcn.lcncidade, 
 lcn.lcncep, lcn.lcnrua, lcn.lcncomp, doc.controle, doc.notcodac, doc.nostiptra, t.prialqicms, t.pribasicms, t.privlicms, t.prialpis, t.privlpis, t.prialcof, t.privlcof,
t.pribaseipi, t.prialqipi, t.pribaspis, t.pritabpre, t.operacao, ddt.ddtdtcol, doc.nostransp, doc.nostredesp, doc.nosplaca,
t.pritripis, t.pritricof, t.priredpisc;

ALTER TABLE pw_faturamento
  OWNER TO postgres;
