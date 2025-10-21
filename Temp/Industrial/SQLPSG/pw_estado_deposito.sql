-- View: pw_estado_deposito

--DROP VIEW pw_estado_deposito;

CREATE OR REPLACE VIEW pw_estado_deposito AS 
 SELECT e.estado AS estadodeposito_codigo_pk,
    e.estnome AS estadodeposito_descricao,
    e.pais AS estadodeposito_paisdeposito_codigo_fk
   FROM estado e
  ORDER BY e.estnome;

ALTER TABLE pw_estado_deposito
  OWNER TO postgres;