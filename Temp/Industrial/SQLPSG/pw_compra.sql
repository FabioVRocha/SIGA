-- View: pw_compra

-- DROP VIEW pw_compra;

CREATE OR REPLACE VIEW pw_compra AS 
 SELECT d.controle AS compra_nf_controle_pk, d.notdocto AS compra_nf_numero, d.notdepori AS compra_deposito_codigo_fk, d.notserie AS compra_nf_serie, d.notsubser AS compra_nf_subserie, d.notespecie AS compra_nf_especie, d.notdata AS compra_data_emissao, d.notentrada AS compra_data_entrada, d.notclifor AS compra_empresa_codigo_fk, d.operacao AS compra_cfop_codigo_fk, toq.priproduto AS compra_produto_codigo_fk, toq.priumnf AS compra_unidade_medida, emp.empcgccpf AS compra_cnpj, sum(toq.priquanti) AS compra_qtde_produto, sum(toq.privltotal + toq.privlipi + toq.privlfrete - toq.privldecon + toq.privlsubst + toq.privldesp * 1::numeric - toq.pridescof - toq.pridespis) AS compra_valor_total, sum(toq.privlipi) AS compra_valor_ipi, sum(toq.privlicms) AS compra_valor_icms, sum(toq.privlsubst) AS compra_valor_subst_tributaria, sum(toq.privlfrete) AS compra_valor_frete, sum(toq.privldecon + toq.pridescof + toq.pridespis) AS compra_valor_desconto, sum(toq.privldesp) AS compra_valor_despesa, sum(toq.privlpis) AS compra_valor_pis, sum(toq.privlcof) AS compra_valor_cofins, sum(toq.privlcsll) AS compra_valor_csll, sum(
        CASE
            WHEN o.opeirrf = 'S'::bpchar AND tot.privltotal > 0::numeric THEN round(toq.privltotal / tot.privltotal * d.notvirrf, 2)
            ELSE 0.00
        END) AS compra_valor_irrf, sum(toq.dstvlritem) AS compra_valor_credito_st, toq.pribaseipi AS compra_base_ipi, toq.privlbipi AS compra_valor_base_ipi, toq.pribasicms AS compra_base_icms, toq.privlbicms AS compra_valor_base_icms, toq.pribaspis AS compra_base_pis, toq.privlbpis AS compra_valor_base_pis, toq.pribaspis AS compra_base_cofins, toq.privlbpis AS compra_valor_base_cofins, toq.prialqipi AS compra_aliquota_ipi, toq.prialqicms AS compra_aliquota_icms, toq.prialpis AS compra_aliquota_pis, toq.prialcof AS compra_aliquota_cofins
   FROM opera o, doctos d
   LEFT JOIN ( SELECT t.itecontrol, t.pricompra, t.priproduto, t.priumnf, t.priquanti, t.privltotal, t.privlipi, t.privlfrete, t.privldecon, t.privlsubst, t.privldesp, t.pridescof, t.pridespis, t.privlicms, t.privlpis, t.privlcof, t.privlcsll, t.operacao, t.pribaseipi, t.privlbipi, t.pribasicms, t.privlbicms, t.pribaspis, t.privlbpis, t.prialqipi, t.prialqicms, t.prialpis, t.prialcof, dst.dstvlritem
           FROM toqmovi t
      LEFT JOIN ( SELECT s.dstcontr, s.dstseq, s.dstvlritem
                   FROM docstlev s) dst ON dst.dstcontr = t.itecontrol AND dst.dstseq = t.prisequen
     WHERE t.prisequen < 500) toq ON toq.itecontrol = d.controle
   LEFT JOIN ( SELECT c.compra, c.comcompr
      FROM compra c) com ON com.compra = toq.pricompra
   LEFT JOIN ( SELECT u.itecontrol, sum(u.privltotal) AS privltotal
   FROM toqmovi u, opera p
  WHERE u.operacao = p.operacao AND p.opeirrf = 'S'::bpchar
  GROUP BY u.itecontrol) tot ON tot.itecontrol = d.controle
   LEFT JOIN ( SELECT e.empresa, e.empcgccpf
   FROM empresa e) emp ON emp.empresa = d.notclifor
  WHERE (d.notdtdigit IS NOT NULL OR d.notdtdigit <> '0001-01-01'::date) AND substr(d.notobsfisc::text, 1, 10) <> 'NF ANULADA'::text AND d.operacao < '4'::bpchar AND d.operacao <> '0'::bpchar AND length(btrim(toq.priproduto::text)) > 0 AND toq.operacao = o.operacao AND length(btrim(d.notdocto::text)) > 0 AND length(btrim(toq.priumnf::text)) > 0 AND length(btrim(emp.empcgccpf::text)) > 0
  GROUP BY d.controle, d.notdocto, d.notdepori, d.notserie, d.notsubser, d.notespecie, d.notdata, d.notentrada, d.notclifor, d.operacao, toq.priproduto, toq.priumnf, toq.pribaseipi, toq.privlbipi, toq.pribasicms, toq.privlbicms, toq.pribaspis, toq.privlbpis, toq.prialqipi, toq.prialqicms, toq.prialpis, toq.prialcof, emp.empcgccpf
UNION ALL 
 SELECT d.controle AS compra_nf_controle_pk, d.notdocto AS compra_nf_numero, d.notdepori AS compra_deposito_codigo_fk, d.notserie AS compra_nf_serie, d.notsubser AS compra_nf_subserie, d.notespecie AS compra_nf_especie, d.notdata AS compra_data_emissao, d.notentrada AS compra_data_entrada, d.notclifor AS compra_empresa_codigo_fk, d.operacao AS compra_cfop_codigo_fk, toq.priproduto AS compra_produto_codigo_fk, toq.priumnf AS compra_unidade_medida, emp.empcgccpf AS compra_cnpj, sum(toq.priquanti) AS compra_qtde_produto, sum(toq.privltotal + toq.privlipi + toq.privlfrete - toq.privldecon + toq.privlsubst + toq.privldesp * 1::numeric - toq.pridescof - toq.pridespis) * (-1)::numeric AS compra_valor_total, sum(toq.privlipi) AS compra_valor_ipi, sum(toq.privlicms) AS compra_valor_icms, sum(toq.privlsubst) AS compra_valor_subst_tributaria, sum(toq.privlfrete) AS compra_valor_frete, sum(toq.privldecon + toq.pridescof + toq.pridespis) AS compra_valor_desconto, sum(toq.privldesp) AS compra_valor_despesa, sum(toq.privlpis) AS compra_valor_pis, sum(toq.privlcof) AS compra_valor_cofins, sum(toq.privlcsll) AS compra_valor_csll, sum(
        CASE
            WHEN o.opeirrf = 'S'::bpchar AND tot.privltotal > 0::numeric THEN round(toq.privltotal / tot.privltotal * d.notvirrf, 2)
            ELSE 0.00
        END) AS compra_valor_irrf, sum(toq.dstvlritem) AS compra_valor_credito_st, toq.pribaseipi AS compra_base_ipi, toq.privlbipi AS compra_valor_base_ipi, toq.pribasicms AS compra_base_icms, toq.privlbicms AS compra_valor_base_icms, toq.pribaspis AS compra_base_pis, toq.privlbpis AS compra_valor_base_pis, toq.pribaspis AS compra_base_cofins, toq.privlbpis AS compra_valor_base_cofins, toq.prialqipi AS compra_aliquota_ipi, toq.prialqicms AS compra_aliquota_icms, toq.prialpis AS compra_aliquota_pis, toq.prialcof AS compra_aliquota_cofins
   FROM opera o, opera p, doctos d
   LEFT JOIN ( SELECT t.itecontrol, t.pricompra, t.priproduto, t.priumnf, t.priquanti, t.privltotal, t.privlipi, t.privlfrete, t.privldecon, t.privlsubst, t.privldesp, t.pridescof, t.pridespis, t.privlicms, t.privlpis, t.privlcof, t.privlcsll, t.operacao, t.pribaseipi, t.privlbipi, t.pribasicms, t.privlbicms, t.pribaspis, t.privlbpis, t.prialqipi, t.prialqicms, t.prialpis, t.prialcof, dst.dstvlritem
           FROM toqmovi t
      LEFT JOIN ( SELECT s.dstcontr, s.dstseq, s.dstvlritem
                   FROM docstlev s) dst ON dst.dstcontr = t.itecontrol AND dst.dstseq = t.prisequen
     WHERE t.prisequen < 500) toq ON toq.itecontrol = d.controle
   LEFT JOIN ( SELECT c.compra, c.comcompr
      FROM compra c) com ON com.compra = toq.pricompra
   LEFT JOIN ( SELECT u.itecontrol, sum(u.privltotal) AS privltotal
   FROM toqmovi u, opera p
  WHERE u.operacao = p.operacao AND p.opeirrf = 'S'::bpchar
  GROUP BY u.itecontrol) tot ON tot.itecontrol = d.controle
   LEFT JOIN ( SELECT e.empresa, e.empcgccpf
   FROM empresa e) emp ON emp.empresa = d.notclifor
  WHERE (d.notdtdigit IS NOT NULL OR d.notdtdigit <> '0001-01-01'::date) AND (d.notentrada IS NULL OR d.notentrada = '0001-01-01'::date) AND substr(d.notobsfisc::text, 1, 10) <> 'NF ANULADA'::text AND d.operacao > '4'::bpchar AND d.operacao = o.operacao AND o.opetransac = 11 AND d.operacao <> '0'::bpchar AND length(btrim(toq.priproduto::text)) > 0 AND toq.operacao = p.operacao AND length(btrim(d.notdocto::text)) > 0 AND length(btrim(toq.priumnf::text)) > 0 AND length(btrim(emp.empcgccpf::text)) > 0
  GROUP BY d.controle, d.notdocto, d.notdepori, d.notserie, d.notsubser, d.notespecie, d.notdata, d.notentrada, d.notclifor, d.operacao, toq.priproduto, toq.priumnf, toq.pribaseipi, toq.privlbipi, toq.pribasicms, toq.privlbicms, toq.pribaspis, toq.privlbpis, toq.prialqipi, toq.prialqicms, toq.prialpis, toq.prialcof, emp.empcgccpf;

ALTER TABLE pw_compra
  OWNER TO postgres;
