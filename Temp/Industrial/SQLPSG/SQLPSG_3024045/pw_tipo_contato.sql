
CREATE OR REPLACE VIEW pw_tipo_contato AS 
 SELECT tipcont.tpcont AS tipocontato_codigo_pk,
    tipcont.tpcond AS tipocontato_descricao,
    tipcont.tpconl AS tipocontato_status
   FROM tipcont
  ORDER BY tipcont.tpcond;

ALTER TABLE pw_tipo_contato
  OWNER TO postgres;
