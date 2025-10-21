-- View: pw_fornecedor_ordem

-- DROP VIEW pw_fornecedor_ordem;

CREATE OR REPLACE VIEW pw_fornecedor_ordem AS 
 SELECT fiordem.fiopord AS fornecedorordem_codigo_pk,
    fiordem.fiopfor AS fornecedorordem_empresa_codigo_fk
   FROM fiordem
  ORDER BY fiordem.fiopord, fiordem.fiopfor;

ALTER TABLE pw_fornecedor_ordem
  OWNER TO postgres;
