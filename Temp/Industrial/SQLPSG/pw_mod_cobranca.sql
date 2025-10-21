-- View: pw_mod_cobranca

-- DROP VIEW pw_mod_cobranca;

CREATE OR REPLACE VIEW pw_mod_cobranca AS 
 SELECT mc.modcobra AS modcobranca_codigo_pk,
    mc.modnome AS modcobranca_descricao
   FROM modcobra mc
  ORDER BY mc.modcobra;

ALTER TABLE pw_mod_cobranca
  OWNER TO postgres;

