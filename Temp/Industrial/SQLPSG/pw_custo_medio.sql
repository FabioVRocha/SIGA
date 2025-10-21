-- View: pw_custo_medio

-- DROP VIEW pw_custo_medio;

CREATE OR REPLACE VIEW pw_custo_medio AS 
 SELECT prod.produto::text || dep.deposito AS customedio_codigo_pk,
    fn_custo_medio(prod.produto, dep.deposito::numeric, '0001-01-01'::date) AS customedio_qtde_custo_medio
   FROM produto prod,
    deposito dep
  ORDER BY prod.produto, dep.deposito;

ALTER TABLE pw_custo_medio
  OWNER TO postgres;
