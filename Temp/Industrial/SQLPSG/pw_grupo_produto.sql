-- View: pw_grupo_produto

-- DROP VIEW pw_grupo_produto;

CREATE OR REPLACE VIEW pw_grupo_produto AS 
 SELECT g.grupo AS grupoproduto_codigo_pk,
    g.grunome AS grupoproduto_descricao,
    g.tgrucod AS grupoproduto_tipo_grupo_produto_codigo_fk
   FROM grupo g
  ORDER BY g.grupo;

ALTER TABLE pw_grupo_produto
  OWNER TO postgres;

