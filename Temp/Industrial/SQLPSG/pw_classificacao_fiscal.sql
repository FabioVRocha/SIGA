-- View: pw_classificacao_fiscal

-- DROP VIEW pw_classificacao_fiscal;

CREATE OR REPLACE VIEW pw_classificacao_fiscal AS 
 SELECT c.clascod AS classificacao_fiscal_codigo_pk,
    c.classifica AS classificacao_fiscal_classificacao,
    c.clanome AS classificacao_fiscal_nome_classificacao
   FROM classi c;

ALTER TABLE pw_classificacao_fiscal
  OWNER TO postgres;
