-- View: pw_acao_assistencia

-- DROP VIEW pw_acao_assistencia;

CREATE OR REPLACE VIEW pw_acao_assistencia AS 
 SELECT a.acocod AS acaoassistencia_codigo_pk,
    a.acodesc AS acaoassistencia_descricao
   FROM acoesas a
  ORDER BY a.acocod;

ALTER TABLE pw_acao_assistencia
  OWNER TO postgres;

