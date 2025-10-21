-- View: pw_conta_reduzida_multa_debito

-- DROP VIEW pw_conta_reduzida_multa_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_multa_debito AS 
 SELECT DISTINCT p.plcproc AS contareduzidamultadebito_codigo_pk,
    p.plcproc AS contareduzidamultadebito_descricao
   FROM planoc p;

ALTER TABLE pw_conta_reduzida_multa_debito
  OWNER TO postgres;