-- View: pw_estado_cobranca

-- DROP VIEW pw_estado_cobranca;

CREATE OR REPLACE VIEW pw_estado_cobranca AS 
 SELECT e.estado AS estadocobranca_codigo_pk,
    e.estnome AS estadocobranca_descricao,
    e.pais AS estadocobranca_paiscobranca_codigo_fk
   FROM estado e
  ORDER BY e.estnome;

ALTER TABLE pw_estado_cobranca
  OWNER TO postgres;