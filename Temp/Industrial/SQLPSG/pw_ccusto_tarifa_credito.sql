-- View: pw_ccusto_tarifa_credito

-- DROP VIEW pw_ccusto_tarifa_credito;

CREATE OR REPLACE VIEW pw_ccusto_tarifa_credito AS 
 SELECT c.ccusto AS ccustotarifacredito_codigo_pk,
    c.ccunome AS ccustotarifacredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_tarifa_credito
  OWNER TO postgres;

