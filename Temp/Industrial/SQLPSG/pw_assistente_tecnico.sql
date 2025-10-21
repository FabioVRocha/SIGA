-- View: pw_assistente_tecnico

-- DROP VIEW pw_assistente_tecnico;

CREATE OR REPLACE VIEW pw_assistente_tecnico AS 
 SELECT e.empresa AS assistentetecnico_codigo_pk,
    e.empnome AS assistentetecnico_descricao,
    e.empfanta AS assistentetecnico_nome_fantasia,
    e.empemail AS assistentetecnico_email_padrao,
        CASE
            WHEN e.empstatus = 'I'::bpchar THEN 'Inativo'::text
            ELSE 'Ativo'::text
        END AS assistentetecnico_status
   FROM empresa e
  WHERE e.emptipo = 5
  ORDER BY e.empnome;

ALTER TABLE pw_assistente_tecnico
  OWNER TO postgres;

