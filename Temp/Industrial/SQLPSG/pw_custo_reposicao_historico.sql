-- View: pw_custo_reposicao_historico

-- DROP VIEW pw_custo_reposicao_historico;

CREATE OR REPLACE VIEW pw_custo_reposicao_historico AS 
 SELECT hiscusto.hicuproco AS custoreposicaohistorico_produto_codigo_fk,
    hiscusto.hicudepo AS custoreposicaohistorico_deposito_codigo_fk,
    hiscusto.hicuvlrcu AS custoreposicaohistorico_custo_reposicao,
    hiscusto.hicudatal AS custoreposicaohistorico_data,
    "substring"(hiscusto.hicuhoral::text, 1, 8) AS custoreposicaohistorico_hora
   FROM hiscusto;

ALTER TABLE pw_custo_reposicao_historico
  OWNER TO postgres;
