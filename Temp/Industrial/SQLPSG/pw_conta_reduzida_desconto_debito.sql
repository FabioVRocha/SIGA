-- View: pw_conta_reduzida_desconto_debito

-- DROP VIEW pw_conta_reduzida_desconto_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_desconto_debito AS 
 SELECT DISTINCT p.plcproc::character(15) AS contareduzidadescontodebito_codigo_pk,
    p.plcproc::character(40) AS contareduzidadescontodebito_descricao
   FROM planoc p;

ALTER TABLE pw_conta_reduzida_desconto_debito
  OWNER TO postgres;

