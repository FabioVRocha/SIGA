-- View: pw_centro_custo

-- DROP VIEW pw_centro_custo;

CREATE OR REPLACE VIEW pw_centro_custo AS 
 SELECT c.ccusto AS centrocusto_codigo_pk,
    c.ccunome AS centrocusto_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_centro_custo
  OWNER TO postgres;

