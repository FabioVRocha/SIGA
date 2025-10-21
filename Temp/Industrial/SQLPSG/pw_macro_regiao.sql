-- View: pw_macro_regiao

-- DROP VIEW pw_macro_regiao;

CREATE OR REPLACE VIEW pw_macro_regiao AS 
 SELECT m.abrmcod AS macro_regiao_codigo_pk,
    m.abrmdes AS macro_regiao_descricao
   FROM abrmac m;

ALTER TABLE pw_macro_regiao
  OWNER TO postgres;

