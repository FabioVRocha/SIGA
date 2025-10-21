-- View: pw_ccusto_multa_debito

-- DROP VIEW pw_ccusto_multa_debito;

CREATE OR REPLACE VIEW pw_ccusto_multa_debito AS 
 SELECT c.ccusto AS ccustomultadebito_codigo_pk,
    c.ccunome AS ccustomultadebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_multa_debito
  OWNER TO postgres;