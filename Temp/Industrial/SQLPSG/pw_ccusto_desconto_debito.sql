-- View: pw_ccusto_desconto_debito

-- DROP VIEW pw_ccusto_desconto_debito;

CREATE OR REPLACE VIEW pw_ccusto_desconto_debito AS 
 SELECT c.ccusto AS ccustodescontodebito_codigo_pk,
    c.ccunome AS ccustodescontodebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_desconto_debito
  OWNER TO postgres;

