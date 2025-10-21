-- View: pw_tipo_venda

-- DROP VIEW pw_tipo_venda;

CREATE OR REPLACE VIEW pw_tipo_venda AS 
 SELECT t.tipoped AS tipovenda_codigo_pk,
    t.tpenome AS tipovenda_descricao
   FROM tipoped t
  ORDER BY t.tipoped;

ALTER TABLE pw_tipo_venda
  OWNER TO postgres;

