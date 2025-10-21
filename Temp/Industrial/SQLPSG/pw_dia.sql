-- View: pw_dia

-- DROP VIEW pw_dia;

CREATE OR REPLACE VIEW pw_dia AS 
 SELECT lpad(generate_series(1, 31)::character varying::text, 2, '0'::text) AS dia_codigo_pk,
    lpad(generate_series(1, 31)::character varying::text, 2, '0'::text) AS dia_descricao;

ALTER TABLE pw_dia
  OWNER TO postgres;

