-- View: pw_ccusto_tarifa_debito

-- DROP VIEW pw_ccusto_tarifa_debito;

CREATE OR REPLACE VIEW pw_ccusto_tarifa_debito AS 
 SELECT c.ccusto AS ccustotarifadebito_codigo_pk,
    c.ccunome AS ccustotarifadebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_tarifa_debito
  OWNER TO postgres;

