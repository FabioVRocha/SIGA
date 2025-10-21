-- View: pw_cidade_cobranca

--DROP VIEW pw_cidade_cobranca

CREATE OR REPLACE VIEW pw_cidade_cobranca AS 
 SELECT 
	c.cidade AS cidadecobranca_codigo_pk,
	c.cidnome AS cidadecobranca_descricao,
	c.estado AS cidadecobranca_estadocobranca_codigo_fk,
	c.cidibge as cidadecobranca_ibge
 FROM 
	cidade c
 ORDER BY c.cidnome;

ALTER TABLE pw_cidade_cobranca
  OWNER TO postgres;