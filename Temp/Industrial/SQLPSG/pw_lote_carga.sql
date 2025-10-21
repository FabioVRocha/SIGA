-- View: pw_lote_carga

-- DROP VIEW pw_lote_carga;

CREATE OR REPLACE VIEW pw_lote_carga AS 
 SELECT l.lcacod AS lotecarga_codigo_pk,
    l.lcades AS lotecarga_descricao,
    l.lcaprev AS lotecarga_data_previsao
   FROM lotecar l
  ORDER BY l.lcacod DESC;

ALTER TABLE pw_lote_carga
  OWNER TO postgres;
