-- View: pw_ordem

--  DROP VIEW pw_ordem;

CREATE OR REPLACE VIEW pw_ordem AS 
 SELECT o.ordem AS ordem_codigo_pk,
    o.tipoord AS ordem_tipo_ordem_fk,
    o.tipoord AS ordem_tipo_ordem_codigo_fk,
    o.lotcod AS ordem_lote_producao_codigo_fk,
        CASE
            WHEN o.ordstatus::text = 'P'::text THEN 'Probl.'::text
            WHEN o.ordlotstat::text = 'ES'::text THEN 'Estati.'::text
            WHEN o.ordlotstat::text = 'FA'::text AND ti.torrepor = 'S'::bpchar THEN 'Fase: '::text || f.fase::text
            WHEN o.ordlotstat::text = 'EP'::text THEN 'Em Proc'::text
            WHEN o.ordlotstat::text = 'EC'::text THEN 'Encerr'::text
            ELSE NULL::text
        END AS ordem_status,
    o.ordproduto AS ordem_produto_codigo_fk,
    o.ordccusto AS ordem_centro_custo_codigo_fk,
    o.ordplanoc AS ordem_plano_contas_codigo_fk,
    o.orddeposit AS ordem_deposito_codigo_fk,
    o.orddtaber AS ordem_data_emissao,
    o.orddtprev AS ordem_data_previsao,
    o.orddtence AS ordem_data_encerramento,
        CASE
            WHEN o.ordinte = 'S'::character(1) THEN 'Sim'::character(3)
            ELSE 'Não'::character(3)
        END AS ordem_indus_terceiro,
    o.ordquanti AS ordem_qtde_digitada    
   FROM ordem o
     LEFT JOIN ( SELECT DISTINCT ON (fas.ordem) fas.ordem,
            fas.fase
           FROM pasfase fas
          ORDER BY fas.ordem, fas.fase DESC, fas.pasdata DESC) f ON f.ordem = o.ordem
     LEFT JOIN ( SELECT tip.tipoord,
            tip.torrepor
           FROM tipoord tip) ti ON ti.tipoord = o.tipoord
  GROUP BY o.lotcod, o.ordem, f.fase, o.ordproduto, o.orddeposit, ti.torrepor, o.ordquanti, o.orddtence, o.tipoord, o.orddtaber, o.orddtprev, o.ordplanoc, o.ordccusto, o.ordinte, o.ordstatus, o.ordlotstat;

ALTER TABLE pw_ordem
  OWNER TO postgres;

