-- View: pw_subgrupo_produto

-- DROP VIEW pw_subgrupo_produto;

CREATE OR REPLACE VIEW pw_subgrupo_produto AS 
 SELECT s.grupo AS subgrupoproduto_grupo_codigo,
    trim(to_char(s.grupo,'000'))||'-'||trim(to_char(s.subgrupo,'000')) AS subgrupoproduto_codigo_pk,	
    s.subgrupo AS subgrupoproduto_cod,
    s.subnome AS subgrupoproduto_descricao,
    s.planoc AS subgrupoproduto_conta_contabil_codigo_fk
   FROM grupo1 s
  ORDER BY s.grupo, s.subgrupo;

ALTER TABLE pw_subgrupo_produto
  OWNER TO postgres;

