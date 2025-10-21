-- View: pw_tipo_titulo

-- DROP VIEW pw_tipo_titulo;

CREATE OR REPLACE VIEW pw_tipo_titulo AS 
 SELECT tt.prtipo AS tipotitulo_codigo_pk,
    tt.prtnome AS tipotitulo_descricao
   FROM prtipo tt
  ORDER BY tt.prtipo;

ALTER TABLE pw_tipo_titulo
  OWNER TO postgres;

