-- View: pw_tipo_movimentacao

-- DROP VIEW pw_tipo_movimentacao;

CREATE OR REPLACE VIEW pw_tipo_movimentacao AS 
 SELECT unnest(ARRAY['S'::text, 'N'::text]) AS tipomovimentacao_codigo_pk,
    unnest(ARRAY['Extra Caixa'::text, 'Não Extra Caixa'::text]) AS tipomovimentacao_decricao;

ALTER TABLE pw_tipo_movimentacao
  OWNER TO postgres;

