-- View: pw_eficiencia_funcionario

-- DROP VIEW pw_eficiencia_funcionario;

CREATE OR REPLACE VIEW pw_eficiencia_funcionario AS 
 SELECT DISTINCT p.plaordem AS eficienciafuncionario_ordem_codigo_fk,
    p.plafuncion AS eficienciafuncionario_funcionario_codigo_fk,
        CASE
            WHEN fn_eficiencia(p.plafuncion, p.plaordem) IS NOT NULL THEN fn_eficiencia(p.plafuncion, p.plaordem)
            ELSE 0::numeric
        END AS eficienciafuncionario_valor_eficiencia
   FROM planilha p
  ORDER BY p.plaordem, p.plafuncion;

ALTER TABLE pw_eficiencia_funcionario
  OWNER TO postgres;