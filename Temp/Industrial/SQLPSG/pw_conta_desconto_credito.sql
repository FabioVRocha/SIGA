-- View: pw_conta_desconto_credito

-- DROP VIEW pw_conta_desconto_credito;

CREATE OR REPLACE VIEW pw_conta_desconto_credito AS 
 SELECT p.planoc AS contadescontocredito_codigo_pk,
    p.plcnome AS contadescontocredito_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_desconto_credito
  OWNER TO postgres;

