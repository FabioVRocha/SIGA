-- View: pw_cfop

-- DROP VIEW pw_cfop;

CREATE OR REPLACE VIEW pw_cfop AS 
 SELECT opera.operacao AS cfop_codigo_pk,
    opera.opedescri AS cfop_descricao,
    opera.opetransac AS cfop_transacao_codigo_fk,
    opera.opeopofi AS cfop_oficial_codigo,
        CASE
            WHEN "substring"(opera.opeopofi::text, 1, 1) = ANY (ARRAY['3'::text, '7'::text]) THEN 'Mercado Externo'::text
            ELSE 'Mercado Interno'::text
        END AS cfop_tipo_mercado
   FROM opera
  ORDER BY opera.operacao;

ALTER TABLE pw_cfop
  OWNER TO postgres;

