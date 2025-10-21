-- View: pw_cidade_deposito

--DROP VIEW pw_cidade_deposito;

CREATE OR REPLACE VIEW pw_cidade_deposito AS 
 SELECT c.cidade AS cidadedeposito_codigo_pk,
    c.cidnome AS cidadedeposito_descricao,
    c.estado AS cidadedeposito_estadodeposito_codigo_fk,
    c.cidibge as cidadedeposito_ibge
   FROM cidade c
  ORDER BY c.cidnome;

ALTER TABLE pw_cidade
  OWNER TO postgres;