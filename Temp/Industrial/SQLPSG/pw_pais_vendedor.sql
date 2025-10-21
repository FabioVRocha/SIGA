-- View: pw_pais_vendedor

-- DROP VIEW pw_pais_vendedor;


CREATE OR REPLACE VIEW pw_pais_vendedor AS 
 SELECT p.pais AS paisvendedor_codigo_pk,
    p.painome AS paisvendedor_descricao,
    p.paiscod as paisvendedor_ibge
   FROM pais p
  ORDER BY p.painome;

ALTER TABLE pw_pais_vendedor
  OWNER TO postgres;
