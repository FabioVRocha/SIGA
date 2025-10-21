-- View: pw_regiao_custo

-- DROP VIEW pw_regiao_custo;

CREATE OR REPLACE VIEW pw_regiao_custo AS 
 SELECT r.regiao AS regiaocusto_codigo_pk,
    r.regnome AS regiaocusto_descricao
   FROM regiao r
  ORDER BY r.regiao;

ALTER TABLE pw_regiao_custo
  OWNER TO postgres;