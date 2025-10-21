-- View: pw_ccusto_iof_debito

-- DROP VIEW pw_ccusto_iof_debito;

CREATE OR REPLACE VIEW pw_ccusto_iof_debito AS 
 SELECT c.ccusto AS ccustoiofdebito_codigo_pk,
    c.ccunome AS ccustoiofdebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_iof_debito
  OWNER TO postgres;

