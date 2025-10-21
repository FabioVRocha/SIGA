-- View pw_tabela_preco_item

 --DROP VIEW pw_tabela_preco_item;

CREATE OR REPLACE VIEW pw_tabela_preco_item AS
 SELECT	btrim(ti.ttpvcod || '-'::text) || btrim(ti.produto) AS tabelaprecoitem_codigo_pk,
	ti.prvenco AS tabelaprecoitem_preco_venda,
	ti.dtprvenda AS tabelaprecoitem_data_preco
 FROM tabprven ti;

ALTER TABLE pw_tabela_preco_item
  OWNER TO postgres;