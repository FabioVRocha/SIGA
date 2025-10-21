-- View: pw_conta_desconto_debito

-- DROP VIEW pw_conta_desconto_debito;

CREATE OR REPLACE VIEW pw_conta_desconto_debito AS 
 SELECT p.planoc AS contadescontodebito_codigo_pk,
    p.plcnome AS contadescontodebito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_desconto_debito
  OWNER TO postgres;

