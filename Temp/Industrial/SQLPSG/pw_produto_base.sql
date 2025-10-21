-- View: pw_produto_base

-- DROP VIEW pw_produto_base;

CREATE OR REPLACE VIEW pw_produto_base AS 
 SELECT p.produto AS produtobase_codigo_pk,
    p.pronome AS produtobase_descricao
   FROM produto p
  ORDER BY p.pronome;

ALTER TABLE pw_produto_base
  OWNER TO postgres;

