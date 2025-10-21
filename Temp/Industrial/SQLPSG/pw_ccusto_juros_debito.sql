-- View: pw_ccusto_juros_debito

-- DROP VIEW pw_ccusto_juros_debito;

CREATE OR REPLACE VIEW pw_ccusto_juros_debito AS 
 SELECT c.ccusto AS ccustojurosdebito_codigo_pk,
    c.ccunome AS ccustojurosdebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;

ALTER TABLE pw_ccusto_juros_debito
  OWNER TO postgres;

