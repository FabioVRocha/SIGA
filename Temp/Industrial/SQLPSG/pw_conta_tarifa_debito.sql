-- View: pw_conta_tarifa_debito

-- DROP VIEW pw_conta_tarifa_debito;

CREATE OR REPLACE VIEW pw_conta_tarifa_debito AS 
 SELECT p.planoc AS contatarifadebito_codigo_pk,
    p.plcnome AS contatarifadebito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_tarifa_debito
  OWNER TO postgres;

