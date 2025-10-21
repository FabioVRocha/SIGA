-- View: pw_conta_juros_debito

-- DROP VIEW pw_conta_juros_debito;

CREATE OR REPLACE VIEW pw_conta_juros_debito AS 
 SELECT p.planoc AS contajurosdebito_codigo_pk,
    p.plcnome AS contajurosdebito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_juros_debito
  OWNER TO postgres;

