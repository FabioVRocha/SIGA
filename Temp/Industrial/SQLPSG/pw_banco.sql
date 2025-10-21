-- View: pw_banco

-- DROP VIEW pw_banco;

CREATE OR REPLACE VIEW pw_banco AS 
 SELECT b.banco AS banco_codigo_pk,
    b.bannome AS banco_descricao
   FROM banco b
  ORDER BY b.banco;

ALTER TABLE pw_banco
  OWNER TO postgres;

