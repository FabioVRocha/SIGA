-- View: pw_transacao

-- DROP VIEW pw_transacao;

CREATE OR REPLACE VIEW pw_transacao AS 
 SELECT t.transacao AS transacao_codigo_pk,
    t.trsnome AS transacao_descricao
   FROM transa t
  ORDER BY t.transacao;

ALTER TABLE pw_transacao
  OWNER TO postgres;

