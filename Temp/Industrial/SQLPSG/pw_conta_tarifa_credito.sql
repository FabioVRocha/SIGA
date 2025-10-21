-- View: pw_conta_tarifa_credito

-- DROP VIEW pw_conta_tarifa_credito;

CREATE OR REPLACE VIEW pw_conta_tarifa_credito AS 
 SELECT p.planoc AS contatarifacredito_codigo_pk,
    p.plcnome AS contatarifacredito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_tarifa_credito
  OWNER TO postgres;

