-- View: pw_cidade_entrega

-- DROP VIEW pw_cidade_entrega;

CREATE OR REPLACE VIEW pw_cidade_entrega AS 
 SELECT c.cidade AS cidadeentrega_codigo_pk, 
		c.cidnome AS cidadeentrega_descricao, 
		c.estado AS cidadeentrega_estado_entrega_codigo_fk,
    c.rgccicod AS cidadeentrega_regiao_carga_codigo_fk
   FROM cidade c
  ORDER BY c.cidnome;

ALTER TABLE pw_cidade_entrega
  OWNER TO postgres;

