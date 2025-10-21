-- View: pw_maquina

-- DROP VIEW pw_maquina;

CREATE OR REPLACE VIEW pw_maquina AS 
 SELECT mq.maquina AS maquina_codigo_pk,
    mq.maqnome AS maquina_descricao
   FROM maquina mq
  ORDER BY mq.maquina;

ALTER TABLE pw_maquina
  OWNER TO postgres;

