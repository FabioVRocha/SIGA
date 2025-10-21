-- View: pw_portador

-- DROP VIEW pw_portador;

CREATE OR REPLACE VIEW pw_portador AS 
 SELECT b.banco AS portador_codigo_pk,
    b.bannome AS portador_descricao
   FROM banco b
  ORDER BY b.banco;

ALTER TABLE pw_portador
  OWNER TO postgres;

