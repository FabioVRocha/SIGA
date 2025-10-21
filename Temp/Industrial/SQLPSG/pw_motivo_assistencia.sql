-- View: pw_motivo_assistencia

-- DROP VIEW pw_motivo_assistencia;

CREATE OR REPLACE VIEW pw_motivo_assistencia AS 
 SELECT m.asmtcod AS motivoassistencia_codigo_pk,
    m.asmtdesc AS motivoassistencia_descricao
   FROM assmoti m
  ORDER BY m.asmtcod;

ALTER TABLE pw_motivo_assistencia
  OWNER TO postgres;

