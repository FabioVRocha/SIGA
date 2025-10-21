-- View: pw_conta_credito

-- DROP VIEW pw_conta_credito;

CREATE OR REPLACE VIEW pw_conta_credito AS 
 SELECT p.planoc AS contacredito_codigo_pk,
    p.plcnome AS contacredito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_credito
  OWNER TO postgres;

