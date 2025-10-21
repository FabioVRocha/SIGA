-- View: pw_ordem_reporte

-- DROP VIEW pw_ordem_reporte;

CREATE OR REPLACE VIEW pw_ordem_reporte AS 
 SELECT r.itecontrol AS ordemreporte_controle_codigo_pk,
    r.prisequen AS ordemreporte_sequencia_codigo_pk,
    r.priordem AS ordemreporte_ordem_codigo_fk,
    r.pridata AS ordemreporte_data_reporte,
    r.priquanti AS ordemreporte_qtde_reportada
   FROM toqmovi r
  WHERE r.priordem <> 0 AND r.pritransac = 3;

ALTER TABLE pw_ordem_reporte
  OWNER TO postgres;

