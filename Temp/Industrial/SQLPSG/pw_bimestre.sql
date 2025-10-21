-- View: pw_bimestre

-- DROP VIEW pw_bimestre;

CREATE OR REPLACE VIEW pw_bimestre AS 
 SELECT lpad(generate_series(1, 6)::character varying::text, 2, '0'::text) AS bimestre_codigo_pk,
    lpad(generate_series(1, 6)::character varying::text, 2, '0'::text) AS bimestre_descricao;

ALTER TABLE pw_bimestre
  OWNER TO postgres;

