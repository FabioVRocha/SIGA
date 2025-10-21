-- View: pw_pais_cobranca

--DROP VIEW pw_pais_cobranca;


CREATE OR REPLACE VIEW pw_pais_cobranca AS 
 SELECT p.pais AS paiscobranca_codigo_pk,
    p.painome AS paiscobranca_descricao,
    p.paiscod as paiscobranca_ibge
   FROM pais p
  ORDER BY p.painome;

ALTER TABLE pw_pais_cobranca
  OWNER TO postgres;
