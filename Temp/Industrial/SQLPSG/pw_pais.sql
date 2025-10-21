-- View: pw_pais

-- DROP VIEW pw_pais;

CREATE OR REPLACE VIEW pw_pais AS 
 SELECT p.pais AS pais_codigo_pk,
    p.painome AS pais_descricao,
    p.paiscod as pais_ibge
   FROM pais p
  ORDER BY p.painome;

ALTER TABLE pw_pais
  OWNER TO postgres;