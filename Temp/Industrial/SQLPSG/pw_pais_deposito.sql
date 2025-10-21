-- View: pw_pais_deposito

--DROP VIEW pw_pais_deposito;


CREATE OR REPLACE VIEW pw_pais_deposito AS 
 SELECT p.pais AS paisdeposito_codigo_pk,
    p.painome AS paisdeposito_descricao,
    p.paiscod as paisdeposito_ibge
   FROM pais p
  ORDER BY p.painome;

ALTER TABLE pw_pais
  OWNER TO postgres;
