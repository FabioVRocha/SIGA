-- View: pw_trimestre

-- DROP VIEW pw_trimestre;

CREATE OR REPLACE VIEW pw_trimestre AS 
 SELECT lpad(generate_series(1, 4)::character varying::text, 2, '0'::text) AS trimestre_codigo_pk,
    lpad(generate_series(1, 4)::character varying::text, 2, '0'::text) AS trimestre_descricao;

ALTER TABLE pw_trimestre
  OWNER TO postgres;

