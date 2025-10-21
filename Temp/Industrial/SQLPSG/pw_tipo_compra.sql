-- View: pw_tipo_compra

-- DROP VIEW pw_tipo_compra;

CREATE OR REPLACE VIEW pw_tipo_compra AS 
 SELECT t.tpctipo AS tipocompra_codigo_pk,
    t.tpcdesc AS tipocompra_descricao
   FROM tipocomp t
  ORDER BY t.tpctipo;

ALTER TABLE pw_tipo_compra
  OWNER TO postgres;

