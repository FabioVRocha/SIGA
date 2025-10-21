-- View: pw_produto

-- DROP VIEW pw_produto;

CREATE OR REPLACE VIEW pw_produto AS 
 SELECT p.produto AS produto_codigo_pk,
    p.pronome AS produto_descricao,
    p.grupo AS produto_grupo_produto_codigo_fk,
    (btrim(to_char(p.grupo::double precision, '000'::text)) || '-'::text) || btrim(to_char(p.subgrupo::double precision, '000'::text)) AS produto_subgrupo_produto_codigo_fk,
    COALESCE(cf.cprefpba, p.produto) AS produto_produto_base_codigo_fk,
    p.prodtinc AS produto_data_cadastro,
    p.clascod AS produto_classificacao_fiscal_codigo_fk,
    p.proesltk AS produto_espessura_lantek,
    p.proliqui AS produto_peso_liquido,
    p.unimedida AS produto_unidade_medida,
    p.prostatus AS produto_status
   FROM produto p
     LEFT JOIN ( SELECT DISTINCT ON (c.cprefpco) c.cprefpba,
            c.cprefpco
           FROM confref c) cf ON cf.cprefpco = p.produto
  ORDER BY p.pronome;

ALTER TABLE pw_produto
  OWNER TO postgres;
