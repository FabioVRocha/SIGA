-- View: pw_operacao

-- DROP VIEW pw_operacao;

CREATE OR REPLACE VIEW pw_operacao AS 
 SELECT op.oppcodi AS operacao_codigo_pk,
    op.oppdesc AS operacao_descricao
   FROM opproc op
  ORDER BY op.oppcodi;

ALTER TABLE pw_operacao
  OWNER TO postgres;

