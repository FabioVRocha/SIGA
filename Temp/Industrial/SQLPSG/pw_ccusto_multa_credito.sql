-- View: pw_ccusto_multa_credito

-- DROP VIEW pw_ccusto_multa_credito;

CREATE OR REPLACE VIEW pw_ccusto_multa_credito AS 
 SELECT c.ccusto AS ccustomultacredito_codigo_pk,
    c.ccunome AS ccustomultacredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_multa_credito
  OWNER TO postgres;