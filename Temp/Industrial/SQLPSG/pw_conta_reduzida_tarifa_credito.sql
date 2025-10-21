-- View: pw_conta_reduzida_tarifa_credito

-- DROP VIEW pw_conta_reduzida_tarifa_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_tarifa_credito AS 
 SELECT DISTINCT p.plcproc AS contareduzidatarifacredito_codigo_pk,
    p.plcproc AS contareduzidatarifacredito_descricao
   FROM planoc p;

ALTER TABLE pw_conta_reduzida_tarifa_credito
  OWNER TO postgres;

