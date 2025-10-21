-- View: pw_pais_entrega

--DROP VIEW pw_pais_cobranca;


CREATE OR REPLACE VIEW pw_pais_entrega AS 
 SELECT p.pais AS paisentrega_codigo_pk,
    p.painome AS paisentrega_descricao,
    p.paiscod as paisentrega_ibge
   FROM pais p
  ORDER BY p.painome;

ALTER TABLE pw_pais_entrega
  OWNER TO postgres;
