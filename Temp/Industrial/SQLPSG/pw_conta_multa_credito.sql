-- View: pw_conta_multa_credito

-- DROP VIEW pw_conta_multa_credito;

CREATE OR REPLACE VIEW pw_conta_multa_credito AS 
 SELECT p.planoc AS contamultacredito_codigo_pk,
    p.plcnome AS contamultacredito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_multa_credito
  OWNER TO postgres;