-- View: pw_estado_entrega

--DROP VIEW pw_estado_entrega;

CREATE OR REPLACE VIEW pw_estado_entrega AS 
 SELECT e.estado AS estadoentrega_codigo_pk,
    e.estnome AS estadoentrega_descricao,
    e.pais AS estadoentrega_pais_entrega_codigo_fk
   FROM estado e
  ORDER BY e.estnome;

ALTER TABLE pw_estado_entrega
  OWNER TO postgres;