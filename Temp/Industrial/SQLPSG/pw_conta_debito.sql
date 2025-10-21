-- View: pw_conta_debito

-- DROP VIEW pw_conta_debito;

CREATE OR REPLACE VIEW pw_conta_debito AS 
 SELECT p.planoc AS contadebito_codigo_pk,
    p.plcnome AS contadebito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_debito
  OWNER TO postgres;

