-- View: pw_conta_multa_debito

-- DROP VIEW pw_conta_multa_debito;

CREATE OR REPLACE VIEW pw_conta_multa_debito AS 
 SELECT p.planoc AS contamultadebito_codigo_pk,
    p.plcnome AS contamultadebito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_multa_debito
  OWNER TO postgres;