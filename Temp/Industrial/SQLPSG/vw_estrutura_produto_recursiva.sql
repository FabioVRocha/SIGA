-- View: vw_estrutura_produto_recursiva

-- DROP VIEW vw_estrutura_produto_recursiva;

CREATE OR REPLACE VIEW vw_estrutura_produto_recursiva AS 
 WITH RECURSIVE custo_rep AS (
         SELECT DISTINCT ON (prodcust.ccrpro) prodcust.ccrpro,
            prodcust.ccrdep,
            prodcust.ccrcus
           FROM prodcust
          WHERE ( SELECT dadosemp.dadmulemp = 'S'::bpchar
                   FROM dadosemp
                  WHERE dadosemp.dadempresa = 1
                 LIMIT 1)
          ORDER BY prodcust.ccrpro, prodcust.ccrdep
        ), nivel_0 AS (
         SELECT p.produto,
            p.pronome,
            p.procusrep,
            c.ccrcus,
            COALESCE(c.ccrcus, p.procusrep) AS custo_reposicao,
            '0' AS nivel
           FROM produto p
             LEFT JOIN custo_rep c ON p.produto = c.ccrpro
          WHERE p.proorigem = 'F'::bpchar
          ORDER BY p.produto
        ), view_estrutura_0 AS (
         SELECT nivel_0.produto,
            row_number() OVER () AS sequencia,
            nivel_0.produto AS produto1,
            nivel_0.pronome,
            nivel_0.nivel,
            nivel_0.custo_reposicao
           FROM nivel_0
        ), parametros_fn_nivel_aux AS (
         SELECT view_estrutura_0.produto,
            view_estrutura_0.produto,
            view_estrutura_0.custo_reposicao,
            view_estrutura_0.sequencia,
            view_estrutura_0.nivel,
            ( SELECT dadosemp.dadmulemp
                   FROM dadosemp
                  WHERE dadosemp.dadempresa = 1
                 LIMIT 1) AS multiempresa
           FROM view_estrutura_0
        ), loop_estrut AS (
         SELECT e.estproduto,
            e.estfilho,
            e.estqtduso
           FROM estrutur e
        ), estrutura_rec(estproduto, estfilho) AS (
         SELECT estrutur.estproduto,
            estrutur.estfilho,
            (estrutur.estproduto::text || ' -> '::text) || estrutur.estfilho::text AS caminho,
            estrutur.estproduto::text AS produto_nivel_0,
            1 AS nivel,
            estrutur.estqtduso AS qtd_estrutura
           FROM estrutur
        UNION
         SELECT child.estproduto,
            child.estfilho,
            (((estrutura_rec.caminho || ' -> '::text) || child.estproduto::text) || ' -> '::text) || child.estfilho::text AS caminho,
            estrutura_rec.produto_nivel_0,
            estrutura_rec.nivel + 1 AS nivel,
            child.estqtduso AS qtd_estrutura
           FROM estrutura_rec
             JOIN estrutur child ON estrutura_rec.estfilho = child.estproduto
        ), estrutura_montada AS (
         SELECT estrutura_rec.estproduto,
            estrutura_rec.estfilho,
            estrutura_rec.caminho,
            estrutura_rec.produto_nivel_0,
            estrutura_rec.nivel,
            estrutura_rec.qtd_estrutura,
            lpad(estrutura_rec.nivel::text, estrutura_rec.nivel + 1, ' '::text) AS nivel_formatado
           FROM estrutura_rec
        UNION
         SELECT DISTINCT ON (estrutura_rec.produto_nivel_0) estrutura_rec.produto_nivel_0 AS estproduto,
            estrutura_rec.produto_nivel_0 AS estfilho,
            estrutura_rec.produto_nivel_0 AS caminho,
            estrutura_rec.produto_nivel_0,
            0 AS nivel,
            estrutura_rec.qtd_estrutura,
            lpad(0::text, 1, ' '::text) AS nivel_formatado
           FROM estrutura_rec
  ORDER BY 4, 3
        ), estrutura_nivel_a_nivel AS (
         SELECT estrutura_montada.produto_nivel_0::character(16) AS produto_filtro,
            estrutura_montada.nivel_formatado::character varying AS nivel,
            row_number() OVER (ORDER BY estrutura_montada.produto_nivel_0, estrutura_montada.caminho) AS sequencia,
            estrutura_montada.estfilho::character(16) AS produto,
            p.pronome AS descricao,
            estrutura_montada.qtd_estrutura AS quantidade_estrutura,
            p.unimedida AS unimedida_estrutura,
            (
                CASE
                    WHEN p.procveng > 0::numeric THEN p.procveng
                    ELSE 1::numeric
                END * estrutura_montada.qtd_estrutura)::numeric(14,4) AS quantidade_engenharia,
                CASE
                    WHEN length(p.prouneng) > 0 THEN p.prouneng
                    ELSE p.unimedida
                END AS unimedida_engenharia,
            c.ccrcus::numeric(14,4) AS custorep_unitario,
            round(estrutura_montada.qtd_estrutura * c.ccrcus, 4)::numeric(14,4) AS custorep_total,
                CASE
                    WHEN custo_produto_nivel_0.ccrcus > 0::numeric THEN round(estrutura_montada.qtd_estrutura * c.ccrcus * 100::numeric / custo_produto_nivel_0.ccrcus, 4)
                    ELSE 0::numeric
                END::numeric(14,4) AS percentual,
            p.proorigem AS origem,
            produto_nivel_0.proorigem AS origem_nivel_0,
            estrutura_montada.nivel AS nivel_numerico
           FROM estrutura_montada
             LEFT JOIN produto p ON p.produto = estrutura_montada.estfilho
             LEFT JOIN produto produto_nivel_0 ON produto_nivel_0.produto::text = estrutura_montada.produto_nivel_0
             LEFT JOIN custo_rep c ON p.produto = c.ccrpro
             LEFT JOIN custo_rep custo_produto_nivel_0 ON estrutura_montada.estproduto = custo_produto_nivel_0.ccrpro
          WHERE produto_nivel_0.proorigem = 'F'::bpchar
          ORDER BY estrutura_montada.produto_nivel_0, estrutura_montada.caminho
        ), fn_estrutura_nivel_a_nivel AS (
         SELECT b.produto_filtro,
            b.nivel,
            b.sequencia,
            b.produto,
            b.descricao,
                CASE
                    WHEN b.nivel_numerico > 0 THEN b.quantidade_estrutura
                    ELSE NULL::numeric
                END AS quantidade_estrutura,
                CASE
                    WHEN b.nivel_numerico > 0 THEN b.unimedida_estrutura
                    ELSE NULL::bpchar
                END AS unimedida_estrutura,
                CASE
                    WHEN b.nivel_numerico > 0 THEN b.quantidade_engenharia
                    ELSE NULL::numeric
                END AS quantidade_engenharia,
                CASE
                    WHEN b.nivel_numerico > 0 THEN b.unimedida_engenharia
                    ELSE NULL::bpchar
                END AS unimedida_engenharia,
            b.custorep_unitario,
                CASE
                    WHEN b.nivel_numerico > 0 THEN b.custorep_total
                    ELSE NULL::numeric
                END AS custorep_total,
                CASE
                    WHEN b.nivel_numerico > 0 THEN b.percentual
                    ELSE NULL::numeric
                END AS percentual
           FROM estrutura_nivel_a_nivel b
        )
 SELECT fn_estrutura_nivel_a_nivel.produto_filtro AS produto_nivel_zero,
    fn_estrutura_nivel_a_nivel.nivel AS nivel_estrutura,
    fn_estrutura_nivel_a_nivel.produto AS codigo_produto,
    fn_estrutura_nivel_a_nivel.descricao AS descricao_produto,
    fn_estrutura_nivel_a_nivel.quantidade_estrutura,
    fn_estrutura_nivel_a_nivel.unimedida_estrutura AS unidade_medida_estrutura,
    fn_estrutura_nivel_a_nivel.quantidade_engenharia,
    fn_estrutura_nivel_a_nivel.unimedida_engenharia AS unidade_medida_engenharia,
    fn_estrutura_nivel_a_nivel.custorep_unitario AS custo_reposicao_unitario,
    fn_estrutura_nivel_a_nivel.custorep_total AS custo_reposicao_total,
    fn_estrutura_nivel_a_nivel.percentual AS percentual_custo_produto_pai
   FROM fn_estrutura_nivel_a_nivel
  ORDER BY fn_estrutura_nivel_a_nivel.produto_filtro, fn_estrutura_nivel_a_nivel.sequencia;

ALTER TABLE vw_estrutura_produto_recursiva
  OWNER TO postgres;

