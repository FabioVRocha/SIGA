-- View: pw_fase_producao

-- DROP VIEW pw_fase_producao;

CREATE OR REPLACE VIEW pw_fase_producao AS 
 SELECT f.fase AS faseproducao_codigo_pk,
    f.fasnome AS faseproducao_descricao
   FROM fases f
  ORDER BY f.fase;

ALTER TABLE pw_fase_producao
  OWNER TO postgres;

