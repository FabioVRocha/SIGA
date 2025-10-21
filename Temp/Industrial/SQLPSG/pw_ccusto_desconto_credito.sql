-- View: pw_ccusto_desconto_credito

-- DROP VIEW pw_ccusto_desconto_credito;

CREATE OR REPLACE VIEW pw_ccusto_desconto_credito AS 
 SELECT c.ccusto AS ccustodescontocredito_codigo_pk,
    c.ccunome AS ccustodescontocredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_desconto_credito
  OWNER TO postgres;

