-- View: pw_ccusto_debito

-- DROP VIEW pw_ccusto_debito;

CREATE OR REPLACE VIEW pw_ccusto_debito AS 
 SELECT c.ccusto AS ccustodebito_codigo_pk,
    c.ccunome AS ccustodebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_debito
  OWNER TO postgres;

