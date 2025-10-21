-- View: pw_previsao

-- DROP VIEW pw_previsao;

CREATE OR REPLACE VIEW pw_previsao AS 
 SELECT een.pescod AS previsao_codigo,
    een.pesdeposit AS previsao_deposito_codigo_fk,
        CASE
            WHEN een.preensai = 'S'::bpchar THEN 'Saida'::text
            ELSE 'Entrada'::text
        END AS previsao_entsai,
    een.pesdata AS previsao_data_vencimento,
    een.peshist AS previsao_descricao,
    een.pesvalor AS previsao_valor_absoluto,
        CASE
            WHEN een.preensai = 'S'::bpchar THEN een.pesvalor * (-1)::numeric
            ELSE een.pesvalor
        END AS previsao_valor_caixa,
        CASE
            WHEN een.pesrealiz = 'S'::bpchar THEN 'Sim'::text
            ELSE 'Nao'::text
        END AS previsao_realizada,
    een.pesdtpgto AS previsao_data_pagamento,
    een.pesobserv AS previsao_observacao,
    een.prtipo AS previsao_tipotitulo_codigo_fk
   FROM preensai een;

ALTER TABLE pw_previsao
  OWNER TO postgres;
