-- View: pw_custos

-- DROP VIEW pw_custos;

CREATE OR REPLACE VIEW pw_custos AS 
 SELECT pw_custo_medio_posicao.customedioposicao_produto_codigo_fk AS "custos_produto_codigo_fk",
    pw_custo_medio_posicao.customedioposicao_deposito_codigo_fk AS "custos_deposito_codigo_fk",
    pw_custo_medio_posicao.customedioposicao_saldo AS "custos_customedioposicao_saldo",
    NULL::numeric AS "custos_custoreposicaohistorico_custo_reposicao",
    pw_custo_medio_posicao.customedioposicao_data_pk AS "custos_data_fk",
    NULL::text AS "custos_hora"
   FROM pw_custo_medio_posicao
UNION ALL
 SELECT pw_custo_reposicao_historico.custoreposicaohistorico_produto_codigo_fk AS "custos_produto_codigo_fk",
    pw_custo_reposicao_historico.custoreposicaohistorico_deposito_codigo_fk AS "custos_deposito_codigo_fk",
    NULL::numeric AS "custos_customedioposicao_saldo",
    pw_custo_reposicao_historico.custoreposicaohistorico_custo_reposicao AS "custos_custoreposicaohistorico_custo_reposicao",
    pw_custo_reposicao_historico.custoreposicaohistorico_data AS "custos_data_fk",
    pw_custo_reposicao_historico.custoreposicaohistorico_hora AS "custos_hora"
   FROM pw_custo_reposicao_historico;

ALTER TABLE pw_custos
  OWNER TO postgres;