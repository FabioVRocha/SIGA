-- View: pw_conta_juros_credito

-- DROP VIEW pw_conta_juros_credito;

CREATE OR REPLACE VIEW pw_conta_juros_credito AS 
 SELECT p.planoc AS contajuroscredito_codigo_pk,
    p.plcnome AS contajuroscredito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_juros_credito
  OWNER TO postgres;

