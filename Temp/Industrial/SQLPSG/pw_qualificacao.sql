-- View: pw_qualificacao

--DROP VIEW pw_qualificacao;

CREATE OR REPLACE VIEW pw_qualificacao AS 
 SELECT q.qualif AS qualificacao_codigo_pk,
    q.quanome AS qualificacao_nome   
   FROM qualific q
  ORDER BY q.qualif;

ALTER TABLE pw_qualificacao
  OWNER TO postgres;

