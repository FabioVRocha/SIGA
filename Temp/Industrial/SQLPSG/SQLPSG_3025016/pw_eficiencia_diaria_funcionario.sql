-- View: pw_eficiencia_diaria_funcionario

-- DROP VIEW pw_eficiencia_diaria_funcionario;

CREATE OR REPLACE VIEW pw_eficiencia_diaria_funcionario AS 
 SELECT DISTINCT p.plaordem AS eficienciadiariafuncionario_ordem_codigo_fk,
    p.plafuncion AS eficienciadiariafuncionario_funcionario_codigo_fk,
        CASE
            WHEN fn_eficiencia(p.plafuncion, p.plaordem, p.pladata, p.pladata) IS NOT NULL THEN fn_eficiencia(p.plafuncion, p.plaordem, p.pladata, p.pladata)
            ELSE 0::numeric
        END AS eficienciadiariafuncionario_valor_eficiencia,
    p.pladata AS eficienciadiariafuncionario_data_planilhamento
   FROM planilha p
  ORDER BY p.plaordem, p.plafuncion;

ALTER TABLE pw_eficiencia_diaria_funcionario
  OWNER TO postgres;
