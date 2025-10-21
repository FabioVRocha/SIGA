-- View: pw_custo_medio_posicao

-- DROP VIEW pw_custo_medio_posicao;

CREATE OR REPLACE VIEW pw_custo_medio_posicao AS 
 SELECT possali1.psidata AS customedioposicao_data_pk,
    possali1.produto::text AS customedioposicao_produto_codigo_fk,
    possali1.deposito::numeric AS customedioposicao_deposito_codigo_fk,
    fn_custo_medio(possali1.produto::text::bpchar, possali1.deposito::numeric, possali1.psidata) AS customedioposicao_qtde_custo_medio,
    possali1.psisaldo AS customedioposicao_saldo
   FROM possali1
  ORDER BY possali1.psidata, possali1.produto, possali1.deposito;

ALTER TABLE pw_custo_medio_posicao
  OWNER TO postgres;
