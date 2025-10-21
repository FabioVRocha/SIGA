-- View: pw_conta_reduzida_iof_debito

-- DROP VIEW pw_conta_reduzida_iof_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_iof_debito AS 
 SELECT DISTINCT p.plcproc AS contareduzidaiofdebito_codigo_pk,
    p.plcproc AS contareduzidaiofdebito_descricao
   FROM planoc p;

ALTER TABLE pw_conta_reduzida_iof_debito
  OWNER TO postgres;

