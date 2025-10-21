-- View: pw_cidade_vendedor

--DROP VIEW pw_cidade_vendedor;

CREATE OR REPLACE VIEW pw_cidade_vendedor AS 
 SELECT c.cidade AS cidadevendedor_codigo_pk,
    c.cidnome AS cidadevendedor_descricao,
    c.estado AS cidadevendedor_estadovendedor_codigo_fk,
    c.cidibge as cidadevendedor_ibge
   FROM cidade c
  ORDER BY c.cidnome;

ALTER TABLE pw_cidade_vendedor
  OWNER TO postgres;