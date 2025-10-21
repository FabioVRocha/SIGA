-- DROP VIEW pw_redespacho;

CREATE OR REPLACE VIEW pw_redespacho AS 
 SELECT e.empresa AS redespacho_codigo_pk,
    e.empnome AS redespacho_descricao,
    e.empfanta AS redespacho_nome_fantasia
 from empresa e
  ORDER BY e.empnome;

ALTER TABLE pw_redespacho
  OWNER TO postgres;
