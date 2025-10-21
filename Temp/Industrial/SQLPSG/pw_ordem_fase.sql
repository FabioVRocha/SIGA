-- View: pw_ordem_fase

-- DROP VIEW pw_ordem_fase;

CREATE OR REPLACE VIEW pw_ordem_fase AS 
 SELECT f.fsororde AS ordemfase_ordem_codigo_fk,
    f.fsorfase AS ordemfase_fase_producao_codigo_fk,
    sum(COALESCE(pf.pasquanti, 0.0000)) AS ordemfase_qtde_passada
   FROM fasord f
     LEFT JOIN ( SELECT pasf.ordem,
            pasf.fase,
            pasf.pasquanti
           FROM pasfase pasf) pf ON f.fsororde = pf.ordem AND f.fsorfase = pf.fase
  GROUP BY f.fsororde, f.fsorfase
  ORDER BY f.fsororde, f.fsorfase;

ALTER TABLE pw_ordem_fase
  OWNER TO postgres;

