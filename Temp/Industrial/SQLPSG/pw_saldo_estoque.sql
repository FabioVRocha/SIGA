-- View: pw_saldo_estoque

-- DROP VIEW pw_saldo_estoque;

CREATE OR REPLACE VIEW pw_saldo_estoque AS 
 SELECT prod.produto AS saldoestoque_produto_codigo_fk,
    dep.deposito AS saldoestoque_deposito_codigo_fk,
    fn_saldo_produto('now'::text::date, prod.produto, dep.deposito::numeric, 0::numeric, 0::numeric) AS saldoestoque_qtde_saldo_estoque,
    prod.produto::text || dep.deposito AS saldoestoque_custo_medio_codigo_fk,
    prod.produto::text || dep.deposito AS saldoestoque_saldo_fiscal_codigo_fk
   FROM produto prod,
    deposito dep
  ORDER BY prod.produto, dep.deposito;

ALTER TABLE pw_saldo_estoque
  OWNER TO postgres;
