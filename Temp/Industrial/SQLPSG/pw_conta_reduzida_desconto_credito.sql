-- View: pw_conta_reduzida_desconto_credito

-- DROP VIEW pw_conta_reduzida_desconto_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_desconto_credito AS 
 SELECT DISTINCT p.plcproc AS contareduzidadescontocredito_codigo_pk,
    p.plcproc AS contareduzidadescontocredito_descricao
   FROM planoc p;

ALTER TABLE pw_conta_reduzida_desconto_credito
  OWNER TO postgres;

