-- View: pw_tipo_grupo_produto

-- DROP VIEW pw_tipo_grupo_produto;

CREATE OR REPLACE VIEW pw_tipo_grupo_produto AS 
 SELECT t.tgrucod AS tipogrupoproduto_codigo_pk,
    t.tgrudesc AS tipogrupoproduto_descricao
   FROM tipgrupo t
  ORDER BY t.tgrucod;

ALTER TABLE pw_tipo_grupo_produto
  OWNER TO postgres;

