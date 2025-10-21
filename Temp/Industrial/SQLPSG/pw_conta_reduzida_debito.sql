-- View: pw_conta_reduzida_debito

-- DROP VIEW pw_conta_reduzida_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_debito AS 
 SELECT DISTINCT r.conta::character(15) AS contareduzidadebito_codigo_pk,
    r.conta::character(15) AS contareduzidadebito_descricao
   FROM ( SELECT c.ctbconclie AS conta
           FROM ctbconem c
        UNION ALL
         SELECT f.ctbconforn AS conta
           FROM ctbconem f
        UNION ALL
         SELECT p.plcproc AS conta
           FROM planoc p) r;

ALTER TABLE pw_conta_reduzida_debito
  OWNER TO postgres;

