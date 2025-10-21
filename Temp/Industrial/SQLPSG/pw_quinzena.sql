-- View: pw_quinzena

-- DROP VIEW pw_quinzena;

CREATE OR REPLACE VIEW pw_quinzena AS 
 SELECT lpad(generate_series(1, 2)::character varying::text, 2, '0'::text) AS quinzena_codigo_pk,
    lpad(generate_series(1, 2)::character varying::text, 2, '0'::text) AS quinzena_descricao;

ALTER TABLE pw_quinzena
  OWNER TO postgres;

