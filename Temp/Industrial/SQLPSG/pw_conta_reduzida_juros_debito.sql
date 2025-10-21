-- View: pw_conta_reduzida_juros_debito

-- DROP VIEW pw_conta_reduzida_juros_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_juros_debito AS 
 SELECT DISTINCT p.plcproc AS contareduzidajurosdebito_codigo_pk,
    p.plcproc AS contareduzidajurosdebito_descricao
   FROM planoc p;

ALTER TABLE pw_conta_reduzida_juros_debito
  OWNER TO postgres;

