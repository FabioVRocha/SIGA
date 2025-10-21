-- View: pw_tipo_titulo_sintetico

-- DROP VIEW pw_tipo_titulo_sintetico;

CREATE OR REPLACE VIEW pw_tipo_titulo_sintetico AS 
 SELECT p.planoc AS tipotitulosintetico_codigo_pk,
    p.plcnome AS tipotitulosintetico_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_tipo_titulo_sintetico
  OWNER TO postgres;

