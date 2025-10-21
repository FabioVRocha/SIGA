-- View: pw_estado_vendedor

--DROP VIEW pw_estado_vendedor;

CREATE OR REPLACE VIEW pw_estado_vendedor AS 
 SELECT e.estado AS estadovendedor_codigo_pk,
    e.estnome AS estadovendedor_descricao,
    e.pais AS estadovendedor_paisvendedor_codigo_fk
   FROM estado e
  ORDER BY e.estnome;

ALTER TABLE pw_estado_vendedor
  OWNER TO postgres;