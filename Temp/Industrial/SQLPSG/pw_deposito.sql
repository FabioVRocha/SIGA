-- View: pw_deposito

--DROP VIEW pw_deposito;

CREATE OR REPLACE VIEW pw_deposito AS 
 SELECT d.deposito AS deposito_codigo_pk,
    d.depnome AS deposito_descricao,
    d.deposito AS deposito_filial_codigo,
    d.depnome AS deposito_filial_descricao,
    d.depdepman AS deposito_subgrupo_codigo,
    d.depdepman AS deposito_grupo_codigo,
    d.depcgc AS deposito_cnpj,
    d.depinest AS deposito_inscricao_estatual,
    d.depcidade as deposito_cidadedeposito_codigo_fk
   FROM deposito d
  ORDER BY d.deposito;

ALTER TABLE pw_deposito
  OWNER TO postgres;

