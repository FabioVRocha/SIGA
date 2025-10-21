-- View: pw_anomes

-- DROP VIEW pw_anomes;

CREATE OR REPLACE VIEW pw_anomes AS 
 SELECT to_char(generate_series('2018-01-01'::date - '10 years'::interval, '2018-06-01'::date + '2 years'::interval, '1 mon'::interval), 'YYYYMM'::text) AS anomes_codigo_pk,
    to_char(generate_series('2018-01-01'::date - '10 years'::interval, '2018-06-01'::date + '2 years'::interval, '1 mon'::interval), 'YYYYMM'::text) AS anomes_descricao;

ALTER TABLE pw_anomes
  OWNER TO postgres;

