-- View: pw_conta_reduzida_tarifa_debito

-- DROP VIEW pw_conta_reduzida_tarifa_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_tarifa_debito AS 
select distinct
       p.plcproc as contareduzidatarifadebito_codigo_pk,
       p.plcproc as contareduzidatarifadebito_descricao
  from planoc p; 

ALTER TABLE pw_conta_reduzida_tarifa_debito
  OWNER TO postgres;

