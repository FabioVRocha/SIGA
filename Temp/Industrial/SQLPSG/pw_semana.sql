-- View: pw_semana

-- DROP VIEW pw_semana;

CREATE OR REPLACE VIEW pw_semana AS 
 SELECT lpad(generate_series(1, 53)::character varying::text, 2, '0'::text) AS semana_codigo_pk,
    lpad(generate_series(1, 53)::character varying::text, 2, '0'::text) AS semana_descricao;

ALTER TABLE pw_semana
  OWNER TO postgres;

