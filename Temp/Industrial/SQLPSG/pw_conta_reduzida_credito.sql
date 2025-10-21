-- View: pw_conta_reduzida_credito

-- DROP VIEW pw_conta_reduzida_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_credito AS 
 SELECT DISTINCT r.conta::character(15) AS contareduzidacredito_codigo_pk,
    r.conta::character(40) AS contareduzidacredito_descricao
   FROM ( SELECT c.ctbconclie AS conta
           FROM ctbconem c
        UNION ALL
         SELECT f.ctbconforn AS conta
           FROM ctbconem f
        UNION ALL
         SELECT p.plcproc AS conta
           FROM planoc p) r;

ALTER TABLE pw_conta_reduzida_credito
  OWNER TO postgres;

