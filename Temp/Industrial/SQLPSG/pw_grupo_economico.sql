-- View: pw_grupo_economico

-- DROP VIEW pw_grupo_economico;

CREATE OR REPLACE VIEW pw_grupo_economico AS 
 SELECT ge.grecodigo AS grupoeconomico_codigo_pk,
    ge.gredescri AS grupoeconomico_descricao
   FROM grupeco ge
  ORDER BY ge.grecodigo;

ALTER TABLE pw_grupo_economico
  OWNER TO postgres;

