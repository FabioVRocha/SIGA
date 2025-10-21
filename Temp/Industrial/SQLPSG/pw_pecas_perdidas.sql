-- View: pw_pecas_perdidas

-- DROP VIEW pw_pecas_perdidas;

CREATE OR REPLACE VIEW pw_pecas_perdidas AS 
 SELECT p.perofscod AS pecasperdidas_ordem_codigo_fk,
    p.perqtdper AS pecasperdidas_qtde,
    p.perdatper AS pecasperdidas_data,
    p.perfasepe AS pecasperdidas_fase_producao_codigo_fk
   FROM perdas p
  ORDER BY p.perofscod, p.perfasepe;

ALTER TABLE pw_pecas_perdidas
  OWNER TO postgres;
