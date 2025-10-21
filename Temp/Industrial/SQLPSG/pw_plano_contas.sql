-- View: pw_plano_contas

-- DROP VIEW pw_plano_contas;

CREATE OR REPLACE VIEW pw_plano_contas AS 
 SELECT p.planoc AS planocontas_codigo_pk,
    p.plcnome AS planocontas_descricao
   FROM planoc p
  ORDER BY p.planoc;

ALTER TABLE pw_plano_contas
  OWNER TO postgres;

