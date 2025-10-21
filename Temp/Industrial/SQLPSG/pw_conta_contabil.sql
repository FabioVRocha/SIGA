-- View: pw_conta_contabil

-- DROP VIEW pw_conta_contabil;

CREATE OR REPLACE VIEW pw_conta_contabil AS 
 SELECT p.planoc AS contacontabil_codigo_pk,
    p.plcnome AS contacontabil_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_conta_contabil
  OWNER TO postgres;
