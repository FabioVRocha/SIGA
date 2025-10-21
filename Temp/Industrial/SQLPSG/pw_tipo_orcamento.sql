-- View: pw_tipo_orcamento

-- DROP VIEW pw_tipo_orcamento;

CREATE OR REPLACE VIEW pw_tipo_orcamento AS 
 SELECT t.tpocodi AS tipoorcamento_codigo_pk,
    t.tpodesc AS tipoorcamento_descricao
   FROM tipoorc t
  ORDER BY t.tpocodi;

ALTER TABLE pw_tipo_orcamento
  OWNER TO postgres;