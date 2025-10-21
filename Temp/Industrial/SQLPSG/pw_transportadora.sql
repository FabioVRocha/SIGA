-- DROP VIEW pw_transportadora;

CREATE OR REPLACE VIEW pw_transportadora AS 
 SELECT e.empresa AS transportadora_codigo_pk,
    e.empnome AS transportadora_descricao,
    e.empfanta AS transportadora_nome_fantasia
 from empresa e
  ORDER BY e.empnome;

ALTER TABLE pw_transportadora
  OWNER TO postgres;
