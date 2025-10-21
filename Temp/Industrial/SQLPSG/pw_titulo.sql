-- View: pw_titulo
-- DROP VIEW pw_titulo;
CREATE OR REPLACE VIEW pw_titulo AS
SELECT t.controle AS titulo_controle_pk,
  t.titulo AS titulo_codigo_pk,
  t.titlitrp::text AS titulo_recpag,
  t.titcfco AS titulo_empresa_codigo_fk,
  CASE
    WHEN com.comnvende IS NULL THEN 0
    ELSE com.comnvende::integer
  END AS titulo_vendedor_codigo_fk,
  t.tittipo AS titulo_tipo_titulo_codigo_fk,
  t.titoperaca AS titulo_cfop_codigo_fk,
  t.titmodcobr AS titulo_mod_cobranca_codigo_fk,
  t.titbanco AS titulo_portador_codigo_fk,
  t.titemissao AS titulo_data_emissao,
  t.titvencto AS titulo_data_vencimento,
  t.titdtpag AS titulo_data_ultimo_pagamento,
  t.titlitsit::text AS titulo_situacao,
  t.titdepori AS titulo_deposito_codigo_fk,
  (
    SELECT array_to_string(
        ARRAY(
          SELECT btrim(u.titdescobs::text) AS btrim
          FROM titobse1 u
          WHERE u.titcont = t.controle
            AND u.tittitulo = t.titulo
        ),
        ' '::text
      ) AS array_to_string
  ) AS titulo_observacao,
  t.titvltotal AS titulo_valor_total,
  t.titvlpag AS titulo_valor_pago,
  (t.titvltotal - t.titvlpag)::numeric(14, 2) AS titulo_valor_saldo,
  t.titjuros AS titulo_valor_acrescimo,
  t.titdesco AS titulo_valor_descontos,
  "int".intbenvio AS titulo_data_envio_banco,
  "int".intbdtret AS titulo_data_retorno_banco,
  "int".intdtapr AS titulo_data_protestar,
  pro.protdata AS titulo_data_protesto,
  doc.notentrada AS titulo_data_entrada,
  CASE
    WHEN t.titcompete IS NOT NULL
    AND t.titcompete <> ''::bpchar THEN to_date(
      '01/'::text || t.titcompete::text,
      'DD/MM/YYYY'::text
    )
    ELSE NULL::date
  END AS titulo_data_competencia,
  doc.notdocto AS titulo_nf_numero,
  t.titdtalt AS titulo_data_alteracao,
  t.tithralt AS titulo_hora_alteracao,
  case
    when d.dudcontrol is null then ''
    when mr.mvfcontrol is not null then 'C/REPRES. '
    else case
      when length(trim(d.dudsitua)) = 0 then 'DESCONTADA'
      when d.dudsitua = 'P' then 'PAGA      '
      when d.dudsitua = 'F' then 'DISPONÍVEL'
      when d.dudsitua = 'B' then 'DEBITADA  '
    end
  end as titulo_situacao_duplicata
FROM titulos t
  LEFT JOIN (
    SELECT c.comncontr,
      c.comnseq,
      c.comnvende
    FROM comnf c
    WHERE c.comnseq = 1
  ) com ON com.comncontr::numeric = t.controle::numeric
  LEFT JOIN (
    SELECT i.intcontrol,
      i.inttitulo,
      i.intbenvio,
      i.intbdtret,
      i.intdtapr
    FROM titbanco i
  ) "int" ON "int".intcontrol::numeric = t.controle::numeric
  AND "int".inttitulo = t.titulo
  LEFT JOIN (
    SELECT p.protcontro,
      p.prottitulo,
      p.protdata
    FROM protesto p
  ) pro ON pro.protcontro::numeric = t.controle::numeric
  AND pro.prottitulo = t.titulo
  LEFT JOIN (
    SELECT d.controle,
      d.notentrada,
      d.notdocto
    FROM doctos d
    WHERE d.notensai = 'E'::bpchar
      OR d.notensai = 'S'::bpchar
  ) doc ON doc.controle::numeric = t.controle::numeric
  left join MOVIREPR mr on mr.mvfcontrol::numeric = t.controle::numeric
  and mr.mvftitulo = t.titulo
  left join dupdes d on d.dudcontrol::numeric = t.controle::numeric
  and d.dudtitulo = t.titulo
WHERE (
    t.tittipo = 'VND'::bpchar
    AND t.titdocto IS NOT NULL
    AND t.titdocto <> ''::bpchar
    OR t.tittipo <> 'VND'::bpchar
  )
  AND (
    t.titrecpag = ANY (ARRAY ['R'::bpchar, 'P'::bpchar])
  );
ALTER TABLE pw_titulo OWNER TO postgres;