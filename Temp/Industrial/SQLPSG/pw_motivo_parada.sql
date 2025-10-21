-- View: pw_motivo_parada

-- DROP VIEW pw_motivo_parada;

CREATE OR REPLACE VIEW pw_motivo_parada AS 
 SELECT m.prdcodi AS motivoparada_codigo_pk,
    m.prddesc AS motivoparada_descricao
   FROM paradas m
  ORDER BY m.prdcodi;

ALTER TABLE pw_motivo_parada
  OWNER TO postgres;

