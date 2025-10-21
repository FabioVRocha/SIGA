-- View: pw_processo

-- DROP VIEW pw_processo;

CREATE OR REPLACE VIEW pw_processo AS 
 SELECT proc.processo AS processo_codigo_pk,
    proc.produto AS produto_codigo_fk,
    proc.prcnome AS processo_descricao,
    proc.prccodig AS processo_operacao_codigo_fk
   FROM processo proc
  ORDER BY proc.produto;

ALTER TABLE pw_processo
  OWNER TO postgres;

