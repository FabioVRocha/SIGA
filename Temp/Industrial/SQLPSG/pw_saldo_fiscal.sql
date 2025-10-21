-- View: pw_saldo_fiscal

-- DROP VIEW pw_saldo_fiscal;

CREATE OR REPLACE VIEW pw_saldo_fiscal AS 
 SELECT prod.produto::text || dep.deposito AS saldofiscal_codigo_pk,
    fn_saldo_fiscal('now'::text::date, prod.produto, dep.deposito::numeric, 0::numeric, 0::numeric) AS saldofiscal_qtde_saldo
   FROM produto prod,
    deposito dep
  ORDER BY prod.produto, dep.deposito;

ALTER TABLE pw_saldo_fiscal
  OWNER TO postgres;