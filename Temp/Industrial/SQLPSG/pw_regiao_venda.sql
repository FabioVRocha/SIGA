-- View: pw_regiao_venda

-- DROP VIEW pw_regiao_venda;
 
 CREATE OR REPLACE VIEW pw_regiao_venda AS 
 SELECT a.abrcod AS regiaovenda_codigo_pk,
    a.abrdes AS regiaovenda_descricao
   FROM abrange a
  ORDER BY a.abrcod;

ALTER TABLE pw_regiao_venda
  OWNER TO postgres;

