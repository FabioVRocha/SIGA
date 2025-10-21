-- View: pw_comprador

-- DROP VIEW pw_comprador;

CREATE OR REPLACE VIEW pw_comprador AS 
 SELECT c.comprador AS comprador_codigo_pk,
    c.compnome AS comprador_descricao,
    c.compcargo AS comprador_cargo,
    c.compemail AS comprador_email
   FROM comprado c
  ORDER BY c.compnome;

ALTER TABLE pw_comprador
  OWNER TO postgres;

