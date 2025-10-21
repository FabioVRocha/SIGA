-- DROP VIEW pw_empresa;

CREATE OR REPLACE VIEW pw_empresa AS 
 SELECT e.empresa AS empresa_codigo_pk,
    e.empnome AS empresa_descricao,
    e.empfanta AS empresa_nome_fantasia,
    e.empbairro AS empresa_bairro,
    e.empemail AS empresa_email_padrao,
    e.empmainfe AS empresa_email_danfe,
    e.empmaibol AS empresa_email_boletos,
    e.empmaicte AS empresa_email_cte,
    e.empcidade AS empresa_cidade_codigo_fk,
        CASE
            WHEN e.empstatus = 'I'::bpchar THEN 'Inativo'::text
            ELSE 'Ativo'::text
        END AS empresa_status,
    g.grecodigo AS empresa_grupo_economico_codigo_fk,
    c.cmeabrcod AS macro_regiao_codigo_fk,
    c.cmeabrmcod AS regiao_abrangencia_codigo_fk,
    c.cmedistan::text AS empresa_distancia_do_cliente,
        CASE
            WHEN e.emppess = 'J'::bpchar THEN
            CASE
                WHEN e.empcgc = '  .   .   /    -  '::bpchar THEN ''::text
                ELSE e.empcgc::text
            END
            ELSE
            CASE
                WHEN e.empcpf = '   .   .   -  '::bpchar THEN ''::text
                ELSE e.empcpf::text
            END
        END AS empresa_cnpj_cpf,
    e.empidenti AS empresa_rg,
    e.empinsest AS empresa_inscricao_estadual,
    e.empdtincl AS empresa_data_criacao,
    e.empdtalt AS empresa_data_alteracao,
    e.emphralt AS empresa_hora_alteracao,
        CASE
            WHEN e.empexp = 'N'::bpchar THEN 'Nacional'::text
            WHEN e.empexp = 'S'::bpchar THEN 'Estrangeira'::text
            ELSE NULL::text
        END AS empresa_origem,
        CASE
            WHEN e.emplimcre >= 9999999.99 THEN 0::numeric
            ELSE e.emplimcre::numeric(10,2)
        END AS empresa_limite_credito,
    string_agg(obs.empobserva::text, '
'::text) AS empresa_observacao,
    e.emprua AS empresa_endereco,
    e.empcep AS empresa_cep,
    e.empcomple AS empresa_complemento,
    e.empendcob AS empresa_endereco_cobranca,
    e.empcepcob AS empresa_cep_cobranca,
    e.empcobcomp AS empresa_complemento_cobranca,
    e.empbaicob AS empresa_bairro_cobranca,
    e.empcidcob AS empresa_cidadecobranca_codigo_fk,
    e.emptelef AS empresa_telefone,
    e.empcelular AS empresa_celular,
    e.empvalid AS empresa_data_validade,
    e.empdpess AS empresa_tipo_pessoa,
    e.empdemptip AS empresa_tipo_empresa,
    e.empwhats AS empresa_whatsapp
   FROM empresa e
     LEFT JOIN ( SELECT gr.grecodigo,
            gr.grempresa
           FROM grupeco1 gr) g ON g.grempresa = e.empresa
     LEFT JOIN ( SELECT cm.cmempresa,
            cm.cmeabrcod,
            cm.cmeabrmcod,
            cm.cmedistan
           FROM cmempres cm) c ON c.cmempresa = e.empresa
     LEFT JOIN empresa1 obs ON obs.empresa = e.empresa
  GROUP BY e.empresa, e.empnome, e.empfanta, e.empbairro, e.empemail, e.empmainfe, e.empmaibol, e.empmaicte, e.empcidade, e.empdtalt, e.emphralt,
        CASE
            WHEN e.empstatus = 'I'::bpchar THEN 'Inativo'::text
            ELSE 'Ativo'::text
        END, g.grecodigo, c.cmeabrcod, c.cmeabrmcod, c.cmedistan::text,
        CASE
            WHEN e.emppess = 'J'::bpchar THEN
            CASE
                WHEN e.empcgc = '  .   .   /    -  '::bpchar THEN ''::text
                ELSE e.empcgc::text
            END
            ELSE
            CASE
                WHEN e.empcpf = '   .   .   -  '::bpchar THEN ''::text
                ELSE e.empcpf::text
            END
        END, e.empidenti, e.empinsest, e.empdtincl,
        CASE
            WHEN e.empexp = 'N'::bpchar THEN 'Nacional'::text
            WHEN e.empexp = 'S'::bpchar THEN 'Estrangeira'::text
            ELSE NULL::text
        END, e.emplimcre, e.emprua, e.empcep, e.empcomple, e.empendcob, e.empcepcob, e.empcobcomp, e.empbaicob, e.empcidcob, e.emptelef, e.empcelular, e.empvalid, e.empdpess, e.empdemptip, e.empwhats
  ORDER BY e.empnome;

ALTER TABLE pw_empresa
  OWNER TO postgres;
