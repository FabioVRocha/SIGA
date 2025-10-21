-- View: pw_planilhamento_hora

-- DROP VIEW pw_planilhamento_hora;

CREATE OR REPLACE VIEW pw_planilhamento_hora AS 
 SELECT p.plaordem AS planilhamentohora_ordem_codigo_fk,
    p.pladata AS planilhamentohora_data_planilhamento,
    p.plamaquina AS planilhamentohora_maquina_codigo_fk,
    p.plafuncion AS planilhamentohora_funcionario_codigo_fk,
    p.plafase AS planilhamentohora_fase_producao_codigo_fk,
    p.plaopera AS planilhamentohora_operacao_codigo_fk,
    p.plaquant AS planilhamentohora_qtde_planilhada,
    p.plagrupo AS planilhamentohora_grupo_ordem,
    p.plahrini AS planilhamentohora_qtde_hora_inicio,
    p.plahrfim AS planilhamentohora_qtde_hora_fim,
    p.plahoras AS planilhamentohora_qtde_tempo_planilhado,
    p.plaproc AS planilhamentohora_processo,
    (((trunc(p.plahoras) + (p.plahoras - trunc(p.plahoras)) * 100::numeric / 60::numeric)) *
    60::numeric) * 60::NUMERIC AS planilhamentohora_qtde_tempo_segundos_planilhado    
   FROM planilha p;

ALTER TABLE pw_planilhamento_hora
  OWNER TO postgres;

