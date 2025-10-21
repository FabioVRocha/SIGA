-- View: pw_cidade

-- DROP VIEW pw_cidade;

CREATE OR REPLACE VIEW pw_cidade AS 
 SELECT c.cidade AS cidade_codigo_pk,
    c.cidnome AS cidade_descricao,
    c.estado AS cidade_estado_codigo_fk,
    c.cidibge as cidade_ibge
   FROM cidade c
  ORDER BY c.cidnome;

ALTER TABLE pw_cidade
  OWNER TO postgres;