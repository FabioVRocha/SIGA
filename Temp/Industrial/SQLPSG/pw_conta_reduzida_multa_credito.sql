-- View: pw_conta_reduzida_multa_credito

-- DROP VIEW pw_conta_reduzida_multa_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_multa_credito AS 
 SELECT DISTINCT p.plcproc AS contareduzidamultacredito_codigo_pk,
    p.plcproc AS contareduzidamultacredito_descricao
   FROM planoc p;

ALTER TABLE pw_conta_reduzida_multa_credito
  OWNER TO postgres;