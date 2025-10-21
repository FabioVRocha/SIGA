-- View: pw_tipo_ordem

-- DROP VIEW pw_tipo_ordem;

CREATE OR REPLACE VIEW pw_tipo_ordem AS 
 SELECT t.tipoord AS tipoordem_codigo_pk,
    t.tornome AS tipoordem_descricao
   FROM tipoord t
  ORDER BY t.tipoord;

ALTER TABLE pw_tipo_ordem
  OWNER TO postgres;

