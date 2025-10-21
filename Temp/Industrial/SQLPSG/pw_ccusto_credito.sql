-- View: pw_ccusto_credito

-- DROP VIEW pw_ccusto_credito;

CREATE OR REPLACE VIEW pw_ccusto_credito AS 
 SELECT c.ccusto AS ccustocredito_codigo_pk,
    c.ccunome AS ccustocredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_credito
  OWNER TO postgres;

