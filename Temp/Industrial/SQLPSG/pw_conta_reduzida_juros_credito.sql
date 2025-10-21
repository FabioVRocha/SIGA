-- View: pw_conta_reduzida_juros_credito

-- DROP VIEW pw_conta_reduzida_juros_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_juros_credito AS 
 SELECT DISTINCT p.plcproc AS contareduzidajuroscredito_codigo_pk,
    p.plcproc AS contareduzidajuroscredito_descricao
   FROM planoc p;

ALTER TABLE pw_conta_reduzida_juros_credito
  OWNER TO postgres;

