-- View: pw_titulo_recuperacao_judicial

-- PSCR0700

-- DROP VIEW pw_titulo_recuperacao_judicial;

CREATE OR REPLACE VIEW pw_titulo_recuperacao_judicial AS 
 SELECT titrjudi.titrjcontr AS titulorecuperacaojudicial_controle_pk, titrjudi.titrjnumti AS titulorecuperacaojudicial_titulo
   FROM titrjudi;

ALTER TABLE pw_titulo_recuperacao_judicial
  OWNER TO postgres;

