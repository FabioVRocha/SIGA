-- View: pw_ano

-- DROP VIEW pw_ano;

CREATE OR REPLACE VIEW pw_ano AS 
 SELECT lpad(generate_series(1995, 2050)::character varying::text, 4, '0'::text) AS ano_codigo_pk,
    lpad(generate_series(1995, 2050)::character varying::text, 4, '0'::text) AS ano_descricao;

ALTER TABLE pw_ano
  OWNER TO postgres;

