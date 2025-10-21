-- View: pw_tipo_assistencia

-- DROP VIEW pw_tipo_assistencia;

CREATE OR REPLACE VIEW pw_tipo_assistencia AS 
 SELECT t.tacodi AS tipoassistencia_codigo_pk,
    t.tadesc AS tipoassistencia_descricao
   FROM tipoass t
  ORDER BY t.tacodi;

ALTER TABLE pw_tipo_assistencia
  OWNER TO postgres;

