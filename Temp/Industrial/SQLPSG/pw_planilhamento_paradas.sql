-- View: pw_planilhamento_paradas

-- DROP VIEW pw_planilhamento_paradas;

CREATE OR REPLACE VIEW pw_planilhamento_paradas AS 
 SELECT p.plpafunci AS planilhamentoparadas_funcionario_codigo_fk,
    p.plpadata AS planilhamentoparadas_data_parada,
    p.plpahrini AS planilhamentoparadas_hora_inicial_parada,
    p.plpahrfim AS planilhamentoparadas_hora_final_parada,
    p.plpaparad AS planilhamentoparadas_motivo_parada_codigo_fk,
    p.plpaordem AS planilhamentoparadas_ordem_codigo_fk,
    p.plpamaqui AS planilhamentoparadas_maquina_codigo_fk,
    p.plpahoras AS planilhamentoparadas_qtde_tempo_parada,
    (((trunc(p.plpahoras) + (p.plpahoras - trunc(p.plpahoras)) * 100::numeric / 60::numeric)) *
    60::numeric) * 60::NUMERIC as planilhamentoparadas_qtde_tempo_segundos_parada    
   FROM plapara p;

ALTER TABLE pw_planilhamento_paradas
  OWNER TO postgres;

