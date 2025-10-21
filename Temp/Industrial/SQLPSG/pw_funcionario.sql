-- View: pw_funcionario

-- DROP VIEW pw_funcionario;

CREATE OR REPLACE VIEW pw_funcionario AS 
 SELECT f.funciona AS funcionario_codigo_pk,
    f.funnome AS funcionario_nome
   FROM funciona f
  ORDER BY f.funciona;

ALTER TABLE pw_funcionario
  OWNER TO postgres;

