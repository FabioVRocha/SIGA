-- View: pw_deposito_fin

-- DROP VIEW pw_deposito_fin;

CREATE OR REPLACE VIEW pw_deposito_fin AS 
 SELECT d.deposito AS depositofin_codigo_pk, d.depnome AS depositofin_descricao, d.deposito AS depositofin_filial_codigo, d.depnome AS depositofin_filial_descricao, d.depdepman AS depositofin_subgrupo_codigo, d.depdepman AS depositofin_grupo_codigo
   FROM deposito d
  ORDER BY d.deposito;

ALTER TABLE pw_deposito_fin
  OWNER TO postgres;

