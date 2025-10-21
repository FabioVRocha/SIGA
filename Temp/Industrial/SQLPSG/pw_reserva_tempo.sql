-- View: pw_reserva_tempo

-- DROP VIEW pw_reserva_tempo;

CREATE OR REPLACE VIEW pw_reserva_tempo AS 
 SELECT r.rprnumero AS reserva_tempo_numero_requisicao_pk,
    r.rprordem AS reservatempo_ordem_codigo_fk,
    r.rprproce AS reservatempo_processo_codigo,
    r.rprproctp AS reservatempo_tipo_processo,
    r.rprprocgr AS reservatempo_processo_alternativo,
    r.rproper AS reservatempo_operacao_codigo_fk,
    r.rprfase AS reservatempo_fase_producao_codigo_fk,
    r.rprmaq AS reservatempo_maquina_codigo_fk,
    r.rprtmpres AS reservatempo_qtde_tempo_reservado,
    r.rprtmpreq AS reservatempo_qtde_tempo_requisitado,
    r.rprtmpset AS reservatempo_qtde_tempo_setup
   FROM respror r;

ALTER TABLE pw_reserva_tempo
  OWNER TO postgres;

