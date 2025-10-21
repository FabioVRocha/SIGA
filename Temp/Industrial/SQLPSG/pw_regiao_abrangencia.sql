-- View: pw_regiao_abrangencia

-- DROP VIEW pw_regiao_abrangencia;

CREATE OR REPLACE VIEW pw_regiao_abrangencia AS 
 SELECT a.abrcod AS regiao_abrangencia_codigo_pk,
    a.abrdes AS regiao_abrangencia_descricao
   FROM abrange a;

ALTER TABLE pw_regiao_abrangencia
  OWNER TO postgres;

