-- View: pw_mes

-- DROP VIEW pw_mes;

CREATE OR REPLACE VIEW pw_mes AS 
 SELECT lpad(generate_series(1, 12)::character varying::text, 2, '0'::text) AS mes_codigo_pk,
    lpad(generate_series(1, 12)::character varying::text, 2, '0'::text) AS mes_descricao;

ALTER TABLE pw_mes
  OWNER TO postgres;

