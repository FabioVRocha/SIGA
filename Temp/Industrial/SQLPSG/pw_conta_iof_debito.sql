-- View: pw_conta_iof_debito

-- DROP VIEW pw_conta_iof_debito;

CREATE OR REPLACE VIEW pw_conta_iof_debito AS 
 SELECT p.planoc AS contaiofdebito_codigo_pk,
    p.plcnome AS contaiofdebito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_iof_debito
  OWNER TO postgres;

