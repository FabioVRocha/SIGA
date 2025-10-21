-- View: pw_ccusto_juros_credito

-- DROP VIEW pw_ccusto_juros_credito;

CREATE OR REPLACE VIEW pw_ccusto_juros_credito AS 
 SELECT c.ccusto AS ccustojuroscredito_codigo_pk,
    c.ccunome AS ccustojuroscredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_juros_credito
  OWNER TO postgres;

