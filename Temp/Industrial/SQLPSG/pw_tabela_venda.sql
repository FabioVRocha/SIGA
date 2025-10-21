-- View: pw_tabela_venda

-- DROP VIEW pw_tabela_venda;

CREATE OR REPLACE VIEW pw_tabela_venda AS 
 SELECT tv.ttpvcod AS tabelavenda_codigo_pk,
    tv.ttpvdes AS tabelavenda_descricao
   FROM tptabprv tv
  ORDER BY tv.ttpvcod;

ALTER TABLE pw_tabela_venda
  OWNER TO postgres;

