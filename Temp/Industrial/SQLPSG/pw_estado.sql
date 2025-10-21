-- View: pw_estado

-- DROP VIEW pw_estado;

CREATE OR REPLACE VIEW pw_estado AS 
 SELECT e.estado AS estado_codigo_pk,
    e.estnome AS estado_descricao,
    e.pais AS estado_pais_codigo_fk,
    e.estibge AS estado_codigo_ibge
   FROM estado e
  ORDER BY e.estnome;

ALTER TABLE pw_estado
  OWNER TO postgres;

