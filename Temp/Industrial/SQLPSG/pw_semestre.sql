-- View: pw_semestre

-- DROP VIEW pw_semestre;

CREATE OR REPLACE VIEW pw_semestre AS 
 SELECT lpad(generate_series(1, 2)::character varying::text, 2, '0'::text) AS semestre_codigo_pk,
    lpad(generate_series(1, 2)::character varying::text, 2, '0'::text) AS semestre_descricao;

ALTER TABLE pw_semestre
  OWNER TO postgres;

