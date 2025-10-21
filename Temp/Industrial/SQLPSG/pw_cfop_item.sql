-- View: pw_cfop_item

-- DROP VIEW pw_cfop_item;

CREATE OR REPLACE VIEW pw_cfop_item AS 
 SELECT opera.operacao AS cfopitem_codigo_pk, opera.opedescri AS cfopitem_descricao, opera.opetransac AS cfopitem_transacao_codigo_fk, opera.opeopofi AS cfopitem_oficial_codigo, 
        CASE
            WHEN "substring"(opera.opeopofi::text, 1, 1) = ANY (ARRAY['3'::text, '7'::text]) THEN 'Mercado Externo'::text
            ELSE 'Mercado Interno'::text
        END AS cfopitem_tipo_mercado
   FROM opera
  ORDER BY opera.operacao;

ALTER TABLE pw_cfop_item
  OWNER TO postgres;
