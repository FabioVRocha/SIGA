-- View: pw_eficiencia_of

-- DROP VIEW pw_eficiencia_of;

CREATE OR REPLACE VIEW pw_eficiencia_of AS 
 SELECT DISTINCT p.plaordem AS eficienciaof_ordem_codigo_fk,
        CASE
            WHEN fn_eficiencia(0, p.plaordem) IS NOT NULL THEN fn_eficiencia(0, p.plaordem)
            ELSE 0::numeric
        END AS eficienciaof_valor_eficiencia
   FROM planilha p
  ORDER BY p.plaordem;        
ALTER TABLE pw_eficiencia_of
  OWNER TO postgres;