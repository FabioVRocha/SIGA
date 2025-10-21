-- View: pw_regiao_carga

-- DROP VIEW pw_regiao_carga;

CREATE OR REPLACE VIEW pw_regiao_carga AS 
 SELECT r.rgccod AS regiaocarga_codigo_pk,
    r.rgcdes AS regiaocarga_descricao
   FROM regcar r
  ORDER BY r.rgccod;

ALTER TABLE pw_regiao_carga
  OWNER TO postgres;

