-- View: pw_lote_producao

-- DROP VIEW pw_lote_producao;

CREATE OR REPLACE VIEW pw_lote_producao AS 
 SELECT l.lotcod AS loteproducao_codigo_pk,
    l.lotdes AS loteproducao_descricao,
        CASE
            WHEN l.lotstatus = 'ES'::bpchar THEN 'Estático'::text
            WHEN l.lotstatus = 'EP'::bpchar THEN 'Em Processo'::text
            WHEN l.lotstatus = 'EC'::bpchar THEN 'Encerrado'::text
            WHEN l.lotstatus = 'SO'::bpchar THEN 'Sem Ordens'::text
            ELSE 'Status não Definido'::text
        END AS loteproducao_status
   FROM loteprod l
  ORDER BY l.lotcod;

ALTER TABLE pw_lote_producao
  OWNER TO postgres;
