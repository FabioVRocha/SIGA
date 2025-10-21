-- View: pw_financeiro
-- DROP VIEW pw_financeiro;
CREATE OR REPLACE VIEW pw_financeiro AS
SELECT fin.financeiro_data_lancamento,
    fin.financeiro_sequencia,
    fin.financeiro_depositofin_codigo_fk,
    fin.financeiro_transacao_financeira_codigo_fk,
    fin.financeiro_titulo_controle_fk,
    fin.financeiro_titulo_codigo_fk,
    fin.financeiro_empresa_codigo_fk,
    fin.financeiro_banco_codigo_fk,
    fin.financeiro_historico,
    fin.financeiro_complemento_historico,
    fin.financeiro_valor_subtotal,
    fin.financeiro_valor_juros,
    fin.financeiro_valor_multa,
    fin.financeiro_valor_desconto,
    fin.financeiro_valor_tarifa,
    fin.financeiro_data_envio_banco,
    fin.financeiro_data_retorno_banco,
    fin.financeiro_data_protestar,
    fin.financeiro_data_protesto,
    fin.financeiro_valor_total_entrada,
    fin.financeiro_valor_total_saida,
    fin.financeiro_caixa_banco,
    fin.financeiro_ccusto_credito_codigo_fk,
    fin.financeiro_conta_credito_codigo_fk,
    CASE
        WHEN fin.financeiro_conta_reduzida_credito_fk IS NULL THEN plc.plcproc::text
        WHEN jur.financeiro_titulo_recuperacao_judicial_controle_fk IS NOT NULL THEN plc.plcproc::text
        ELSE fin.financeiro_conta_reduzida_credito_fk
    END AS financeiro_conta_reduzida_credito_codigo_fk,
    fin.financeiro_ccusto_debito_codigo_fk,
    fin.financeiro_conta_debito_codigo_fk,
    CASE
        WHEN fin.financeiro_conta_reduzida_debito_fk IS NULL THEN pld.plcproc::text
        ELSE fin.financeiro_conta_reduzida_debito_fk
    END AS financeiro_conta_reduzida_debito_codigo_fk,
    fin.financeiro_ccusto_juros_credito_codigo_fk,
    fin.financeiro_conta_juros_credito_codigo_fk,
    pjc.plcproc AS financeiro_conta_reduzida_juros_credito_codigo_fk,
    fin.financeiro_ccusto_juros_debito_codigo_fk,
    fin.financeiro_conta_juros_debito_codigo_fk,
    pjd.plcproc AS financeiro_conta_reduzida_juros_debito_codigo_fk,
    fin.financeiro_ccusto_desconto_credito_codigo_fk,
    fin.financeiro_conta_desconto_credito_codigo_fk,
    pdc.plcproc AS financeiro_conta_reduzida_desconto_credito_codigo_fk,
    fin.financeiro_ccusto_desconto_debito_codigo_fk,
    fin.financeiro_conta_desconto_debito_codigo_fk,
    pdd.plcproc AS financeiro_conta_reduzida_desconto_debito_codigo_fk,
    fin.financeiro_ccusto_tarifa_credito_codigo_fk,
    fin.financeiro_conta_tarifa_credito_codigo_fk,
    ptc.plcproc AS financeiro_conta_reduzida_tarifa_credito_codigo_fk,
    fin.financeiro_ccusto_tarifa_debito_codigo_fk,
    fin.financeiro_conta_tarifa_debito_codigo_fk,
    ptd.plcproc AS financeiro_conta_reduzida_tarifa_debito_codigo_fk,
    fin.financeiro_ccusto_iof_debito_codigo_fk,
    fin.financeiro_conta_iof_debito_codigo_fk,
    pid.plcproc AS financeiro_conta_reduzida_iof_debito_codigo_fk,
    fin.financeiro_tipo_movimentacao_codigo_fk,
    fin.financeiro_ccusto_multa_credito_codigo_fk,
    fin.financeiro_conta_multa_credito_codigo_fk,
    fin.financeiro_conta_reduzida_multa_credito_codigo_fk,
    fin.financeiro_conta_juros_debito_codigo_fk AS financeiro_conta_multa_debito_codigo_fk,
    fin.financeiro_ccusto_juros_debito_codigo_fk AS financeiro_ccusto_multa_debito_codigo_fk,
    pjd.plcproc AS financeiro_conta_reduzida_multa_debito_codigo_fk
FROM (
        SELECT l.laclanca AS financeiro_data_lancamento,
            l.lacseq AS financeiro_sequencia,
            l.lacdeposit AS financeiro_depositofin_codigo_fk,
            l.lactransa AS financeiro_transacao_financeira_codigo_fk,
            l.laccontrol AS financeiro_titulo_controle_fk,
            l.lactitulo AS financeiro_titulo_codigo_fk,
            CASE
                WHEN l.lactransa = ANY (
                    ARRAY ['1'::bpchar, '2'::bpchar, '3'::bpchar, '4'::bpchar, '5'::bpchar, '6'::bpchar, '7'::bpchar, '8'::bpchar]
                ) THEN vlant.vlaempresa
                ELSE tit.titcfco
            END AS financeiro_empresa_codigo_fk,
            CASE
                WHEN NOT deb.lacbanco IS NULL THEN deb.lacbanco
                WHEN NOT rec.lacbanco IS NULL THEN rec.lacbanco
                WHEN NOT lam.lacbanco IS NULL THEN lam.lacbanco
                WHEN NOT sac.lacbanco IS NULL THEN sac.lacbanco
                WHEN NOT dud.lacbanco IS NULL THEN dud.lacbanco
                ELSE l.lacbanco
            END AS financeiro_banco_codigo_fk,
            l.historico AS financeiro_historico,
            l.lacdescri AS financeiro_complemento_historico,
            GREATEST(l.lacvltot, 0.00) AS financeiro_valor_subtotal,
            GREATEST(l.lacjuros, 0.00) AS financeiro_valor_juros,
            GREATEST(l.lacmulta, 0.00) AS financeiro_valor_multa,
            GREATEST(l.lacdesco, 0.00) AS financeiro_valor_desconto,
            GREATEST(l.lactarifa, 0.00) AS financeiro_valor_tarifa,
            "int".intbenvio AS financeiro_data_envio_banco,
            "int".intbdtret AS financeiro_data_retorno_banco,
            "int".intdtapr AS financeiro_data_protestar,
            pro.protdata AS financeiro_data_protesto,
            CASE
                WHEN l.lactransa = ANY (
                    ARRAY ['R'::bpchar, 'D'::bpchar, 'F'::bpchar, 'E'::bpchar, 'U'::bpchar, '1'::bpchar, '2'::bpchar, '7'::bpchar, '8'::bpchar, 'G'::bpchar, 'Z'::bpchar, '9'::bpchar, 'Y'::bpchar, 'H'::bpchar, 'N'::bpchar, 'J'::bpchar, 'K'::bpchar, '"'::bpchar]
                ) THEN GREATEST(
                    l.lacvltot + (
                        l.lacjuros - l.lacdesco + GREATEST(l.lactarifa, 0.00) + l.lacmulta
                    ),
                    0.00
                )
                ELSE 0.00
            END AS financeiro_valor_total_entrada,
            CASE
                WHEN l.lactransa = ANY (
                    ARRAY ['P'::bpchar, 'S'::bpchar, 'Q'::bpchar, 'T'::bpchar, '3'::bpchar, '4'::bpchar, '5'::bpchar, '6'::bpchar, 'M'::bpchar, 'X'::bpchar, '0'::bpchar, 'C'::bpchar, 'B'::bpchar, 'Y'::bpchar, 'A'::bpchar, 'I'::bpchar, 'V'::bpchar]
                ) THEN GREATEST(
                    l.lacvltot + (
                        l.lacjuros - l.lacdesco + GREATEST(l.lactarifa, 0.00)
                    ),
                    0.00
                )
                ELSE 0.00
            END AS financeiro_valor_total_saida,
            CASE
                WHEN l.lactransa = ANY (
                    ARRAY ['C'::bpchar, 'G'::bpchar, 'M'::bpchar, 'P'::bpchar, 'R'::bpchar, 'X'::bpchar, 'Y'::bpchar, 'Z'::bpchar, '0'::bpchar, '1'::bpchar, '3'::bpchar, '5'::bpchar, '7'::bpchar, '9'::bpchar, 'V'::bpchar, '"'::bpchar]
                ) THEN 'Caixa'::text
                WHEN l.lactransa = ANY (
                    ARRAY ['A'::bpchar, 'B'::bpchar, 'D'::bpchar, 'E'::bpchar, 'F'::bpchar, 'H'::bpchar, 'I'::bpchar, 'J'::bpchar, 'K'::bpchar, 'N'::bpchar, 'Q'::bpchar, 'S'::bpchar, '2'::bpchar, '4'::bpchar, '6'::bpchar, '8'::bpchar, 'T'::bpchar, 'U'::bpchar]
                ) THEN 'Banco'::text
                ELSE NULL::text
            END AS financeiro_caixa_banco,
            CASE
                WHEN l.lactransa = 'A'::bpchar THEN deb.lacccusto::text
                WHEN l.lactransa = 'B'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = 'D'::bpchar THEN dep.pcxcccaixa::text
                WHEN l.lactransa = 'Q'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = 'T'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'E'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'H'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '1'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '2'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '4'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = '9'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '0'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = 'G'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'F'::bpchar THEN dep.pcxcccheq::text
                WHEN l.lactransa = 'N'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'R'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'P'::bpchar THEN dep.pcxcccaixa::text
                WHEN l.lactransa = '8'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '3'::bpchar THEN dep.pcxcccaixa::text
                WHEN l.lactransa = 'J'::bpchar THEN dep.pcxcccheq::text
                WHEN l.lactransa = 'Y'::bpchar THEN dep.pcxcccheq::text
                WHEN l.lactransa = '6'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = 'S'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '5'::bpchar THEN dep.pcxcccaixa::text
                WHEN l.lactransa = '7'::bpchar THEN l.lacccusto::text
                when l.lactransa = 'M'::bpchar then case
                    when lac.lactransa = 'P'::bpchar then case
                        when lcmul.constalacmul > 0 then case
                            when chq.constachquso1 > 0 then case
                                when length(btrim(prt1.prt1pcdeb::text)) > 0 then prt1.prt1ccdeb::text
                                else case
                                    when length(btrim(prt12.prt1pcdeb::text)) > 0 then prt12.prt1ccdeb::text
                                    else ''::text
                                end
                            end
                            else case
                                when chq2.constachquso2 > 0
                                and cprm.naopreenchidopcxpccheq = 0 then dep.pcxcccaixa::text
                                else dep.pcxcccheq::text
                            end
                        end
                        else null::text
                    end
                    else lac.lacccusto::text
                end
                else ''::text
            END AS financeiro_ccusto_credito_codigo_fk,
            CASE
                WHEN l.lactransa = 'A'::bpchar THEN deb.lacplanoc::text
                WHEN l.lactransa = 'B'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = 'D'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = 'Q'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = 'T'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'E'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'H'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '1'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '2'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '4'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = '9'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '0'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = 'G'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'F'::bpchar THEN dep.pcxpccheq::text
                WHEN l.lactransa = 'N'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'R'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'P'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = '8'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '3'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = 'J'::bpchar THEN dep.pcxpccheq::text
                WHEN l.lactransa = 'Y'::bpchar THEN dep.pcxpccheq::text
                WHEN l.lactransa = '6'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = 'S'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '5'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = '7'::bpchar THEN l.lacplanoc::text
                when l.lactransa = 'M'::bpchar then case
                    when lac.lactransa = 'P'::bpchar then case
                        when lcmul.constalacmul > 0 then case
                            when chq.constachquso1 > 0 then case
                                when length(btrim(prt1.prt1pcdeb::text)) > 0 then prt1.prt1pcdeb::text
                                else case
                                    when length(btrim(prt12.prt1pcdeb::text)) > 0 then prt12.prt1pcdeb::text
                                    else ''::text
                                end
                            end
                            else case
                                when chq2.constachquso2 > 0
                                and cprm.naopreenchidopcxpccheq = 0 then dep.pcxpccaixa::text
                                else dep.pcxpccheq::text
                            end
                        end
                        else null::text
                    end
                    else case
                        when dep.pcxchpro = 'C'::bpchar then dep.pcxpcchpro::text
                        else lac.lacplanoc::text
                    end
                end
                ELSE ''::text
            END AS financeiro_conta_credito_codigo_fk,
            CASE
                WHEN (
                    l.lactransa = ANY (
                        ARRAY ['R'::bpchar, 'E'::bpchar, 'G'::bpchar, 'H'::bpchar, '9'::bpchar]
                    )
                )
                AND tit.ctbconclie IS NOT NULL THEN tit.ctbconclie::text
                WHEN (
                    l.lactransa = ANY (
                        ARRAY ['R'::bpchar, 'E'::bpchar, 'G'::bpchar, 'H'::bpchar, '9'::bpchar]
                    )
                )
                AND tit.ctbconclie IS NULL
                AND tit.rez_ctbconclie IS NOT NULL THEN tit.rez_ctbconclie::text
                WHEN (
                    l.lactransa = ANY (
                        ARRAY ['R'::bpchar, 'E'::bpchar, 'G'::bpchar, 'H'::bpchar, '9'::bpchar]
                    )
                )
                AND crd.plcproc IS NOT NULL
                AND tit.rez_ctbconclie IS NULL THEN crd.plcproc::text
                ELSE NULL::text
            END AS financeiro_conta_reduzida_credito_fk,
            CASE
                WHEN l.lactransa = 'A'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'B'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'D'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'Q'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'U'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'E'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = 'H'::bpchar THEN rec.lacccusto::text
                WHEN l.lactransa = '1'::bpchar THEN dep.pcxcccaixa::text
                WHEN l.lactransa = '2'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = '4'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '9'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = '0'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'G'::bpchar THEN dep.pcxcccheq::text
                WHEN l.lactransa = 'F'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'R'::bpchar THEN dep.pcxcccaixa::text
                WHEN l.lactransa = 'P'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '8'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = '3'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'J'::bpchar THEN aux.laaccusto::text
                WHEN l.lactransa = 'Y'::bpchar THEN dep.pcxcccaixa::text
                WHEN l.lactransa = '6'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = 'S'::bpchar THEN dep.pcxcccaixa::text
                WHEN l.lactransa = '5'::bpchar THEN l.lacccusto::text
                WHEN l.lactransa = '7'::bpchar THEN dep.pcxcccaixa::text
                when l.lactransa = 'M'::bpchar then l.lacccusto::text
                ELSE ''::text
            END AS financeiro_ccusto_debito_codigo_fk,
            CASE
                WHEN l.lactransa = 'A'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'B'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'D'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'Q'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'U'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'E'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = 'H'::bpchar THEN rec.lacplanoc::text
                WHEN l.lactransa = '1'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = '2'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = '4'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '9'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = '0'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'G'::bpchar THEN dep.pcxpccheq::text
                WHEN l.lactransa = 'F'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'R'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = 'P'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '8'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = '3'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'J'::bpchar THEN aux.laaplanoc::text
                WHEN l.lactransa = 'Y'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = '6'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = 'S'::bpchar THEN dep.pcxpccaixa::text
                WHEN l.lactransa = '5'::bpchar THEN l.lacplanoc::text
                WHEN l.lactransa = '7'::bpchar THEN dep.pcxpccaixa::text
                when l.lactransa = 'M'::bpchar then l.lacplanoc::text
                ELSE ''::text
            END AS financeiro_conta_debito_codigo_fk,
            CASE
                WHEN (
                    l.lactransa = ANY (
                        ARRAY ['P'::bpchar, 'Q'::bpchar, 'M'::bpchar, 'A'::bpchar, 'I'::bpchar, '0'::bpchar]
                    )
                )
                AND tit.ctbconforn IS NOT NULL THEN tit.ctbconforn::text
                WHEN (
                    l.lactransa = ANY (
                        ARRAY ['P'::bpchar, 'Q'::bpchar, 'M'::bpchar, 'A'::bpchar, 'I'::bpchar, '0'::bpchar]
                    )
                )
                AND tit.ctbconforn IS NULL
                AND tit.rez_ctbconforn IS NOT NULL THEN tit.rez_ctbconforn::text
                ELSE NULL::text
            END AS financeiro_conta_reduzida_debito_fk,
            CASE
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'G'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'H'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN aux.laaccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'R'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = '9'::bpchar THEN jur.lajjccusto::text
                ELSE ''::text
            END AS financeiro_ccusto_juros_credito_codigo_fk,
            CASE
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'G'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'H'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN aux.laaplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'R'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = '9'::bpchar THEN jur.lajjplanoc::text
                ELSE ''::text
            END AS financeiro_conta_juros_credito_codigo_fk,
            CASE
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'A'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN aux.laaccusto::text
                WHEN dup.dudjuros > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN dep.pcxccjurpa::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'I'::bpchar THEN jur.lajjccusto::text
                WHEN che.chvlrjuros > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN dep.pcxccjurpa::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'M'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'P'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = '0'::bpchar THEN jur.lajjccusto::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'R'::bpchar THEN dep.pcxcccheq::text
                ELSE ''::text
            END AS financeiro_ccusto_juros_debito_codigo_fk,
            CASE
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'A'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN aux.laaplanoc::text
                WHEN dup.dudjuros > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN dep.pcxpcjurpa::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'I'::bpchar THEN jur.lajjplanoc::text
                WHEN che.chvlrjuros > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN dep.pcxpcjurpa::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'M'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'P'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = '0'::bpchar THEN jur.lajjplanoc::text
                WHEN l.lacjuros > 0::numeric
                AND l.lactransa = 'R'::bpchar THEN dep.pcxpccheq::text
                ELSE NULL::text
            END AS financeiro_conta_juros_debito_codigo_fk,
            CASE
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'A'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'I'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'M'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'P'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = '0'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'R'::bpchar THEN l.lacccusto::text
                ELSE ''::text
            END AS financeiro_ccusto_desconto_credito_codigo_fk,
            CASE
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'A'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'I'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'M'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'P'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = '0'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'R'::bpchar THEN l.lacplanoc::text
                ELSE ''::text
            END AS financeiro_conta_desconto_credito_codigo_fk,
            CASE
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN aux.laaccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'G'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'H'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN aux.laaccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'R'::bpchar THEN jur.lajdccusto::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = '9'::bpchar THEN jur.lajdccusto::text
                ELSE ''::text
            END AS financeiro_ccusto_desconto_debito_codigo_fk,
            CASE
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN aux.laaplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'G'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'H'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN aux.laaplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = 'R'::bpchar THEN jur.lajdplanoc::text
                WHEN l.lacdesco > 0::numeric
                AND l.lactransa = '9'::bpchar THEN jur.lajdplanoc::text
                ELSE ''::text
            END AS financeiro_conta_desconto_debito_codigo_fk,
            CASE
                WHEN l.lactarifa > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN aux.laaccusto::text
                ELSE ''::text
            END AS financeiro_ccusto_tarifa_credito_codigo_fk,
            CASE
                WHEN l.lactarifa > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN aux.laaplanoc::text
                ELSE ''::text
            END AS financeiro_conta_tarifa_credito_codigo_fk,
            CASE
                WHEN dup.dudtarifa > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN dep.pcxccdespb::text
                WHEN che.chvltarifa > 0::numeric
                AND l.lactransa = 'J'::bpchar THEN dep.pcxccdespb::text
                WHEN l.lactarifa > 0::numeric
                AND l.lactransa = 'P'::bpchar THEN jur.lajtccusto::text
                WHEN l.lactarifa > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN jur.lajtccusto::text
                ELSE ''::text
            END AS financeiro_ccusto_tarifa_debito_codigo_fk,
            CASE
                WHEN dup.dudtarifa > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN dep.pcxpcdespb::text
                WHEN che.chvltarifa > 0::numeric
                AND l.lactransa = 'J'::bpchar THEN dep.pcxpcdespb::text
                WHEN l.lactarifa > 0::numeric
                AND l.lactransa = 'P'::bpchar THEN jur.lajtplanoc::text
                WHEN l.lactarifa > 0::numeric
                AND l.lactransa = 'Q'::bpchar THEN jur.lajtplanoc::text
                ELSE ''::text
            END AS financeiro_conta_tarifa_debito_codigo_fk,
            CASE
                WHEN dup.dudiof > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN dep.pcxcciof::text
                WHEN che.chvlriof > 0::numeric
                AND l.lactransa = 'J'::bpchar THEN dep.pcxcciof::text
                ELSE ''::text
            END AS financeiro_ccusto_iof_debito_codigo_fk,
            CASE
                WHEN dup.dudiof > 0::numeric
                AND l.lactransa = 'E'::bpchar THEN dep.pcxpciof::text
                WHEN che.chvlriof > 0::numeric
                AND l.lactransa = 'J'::bpchar THEN dep.pcxpciof::text
                ELSE ''::text
            END AS financeiro_conta_iof_debito_codigo_fk,
            CASE
                WHEN l.lactransa = ANY (
                    ARRAY ['V'::bpchar, '"'::bpchar, 'X'::bpchar, '0'::bpchar, 'Z'::bpchar, '9'::bpchar]
                ) THEN 'S'::character(1)
                ELSE 'N'::character(1)
            END AS financeiro_tipo_movimentacao_codigo_fk,
            jur.lajmred AS financeiro_conta_reduzida_multa_credito_codigo_fk,
            jur.lajmplanoc AS financeiro_conta_multa_credito_codigo_fk,
            jur.lajmccusto AS financeiro_ccusto_multa_credito_codigo_fk
        FROM lancai l
            LEFT JOIN (
                SELECT d.deposito,
                    d.depdepman,
                    par.pcxparam,
                    par.pcxpccaixa,
                    par.pcxpccli,
                    par.pcxpcfor,
                    par.pcxpcjurco,
                    par.pcxpcdesco,
                    par.pcxpcjurpa,
                    par.pcxpcdesre,
                    par.pcxpcadsal,
                    par.pcxpcdupde,
                    par.pcxpcdespb,
                    par.pcxpcant,
                    par.pcxpcfan,
                    par.pcxpcvvi,
                    par.pcxpccvi,
                    par.pcxpccomi,
                    par.pcxpcdvven,
                    par.pcxpcdvcom,
                    par.pcxpctrati,
                    par.pcxpciof,
                    par.pcxpccheq,
                    par.pcxpcchpro,
                    par.pcxpctarif,
                    par.pcxpccarta,
                    par.pcxcccaixa,
                    par.pcxcccli,
                    par.pcxccfor,
                    par.pcxccjurco,
                    par.pcxccdesco,
                    par.pcxccjurpa,
                    par.pcxccdesre,
                    par.pcxccadsal,
                    par.pcxccdupde,
                    par.pcxccdespb,
                    par.pcxccant,
                    par.pcxccfan,
                    par.pcxccvvi,
                    par.pcxcccvi,
                    par.pcxcccomi,
                    par.pcxccdvven,
                    par.pcxccdvcom,
                    par.pcxcctrati,
                    par.pcxcciof,
                    par.pcxcccheq,
                    par.pcxctarifa,
                    par.pcxcccarta,
                    par.pcxchpro
                FROM deposito d
                    LEFT JOIN (
                        SELECT p.pcxparam,
                            p.pcxpccaixa,
                            p.pcxpccli,
                            p.pcxpcfor,
                            p.pcxpcjurco,
                            p.pcxpcdesco,
                            p.pcxpcjurpa,
                            p.pcxpcdesre,
                            p.pcxpcadsal,
                            p.pcxpcdupde,
                            p.pcxpcdespb,
                            p.pcxpcant,
                            p.pcxpcfan,
                            p.pcxpcvvi,
                            p.pcxpccvi,
                            p.pcxpccomi,
                            p.pcxpcdvven,
                            p.pcxpcdvcom,
                            p.pcxpctrati,
                            p.pcxpciof,
                            p.pcxpccheq,
                            p.pcxpcchpro,
                            p.pcxpctarif,
                            p.pcxpccarta,
                            p.pcxcccaixa,
                            p.pcxcccli,
                            p.pcxccfor,
                            p.pcxccjurco,
                            p.pcxccdesco,
                            p.pcxccjurpa,
                            p.pcxccdesre,
                            p.pcxccadsal,
                            p.pcxccdupde,
                            p.pcxccdespb,
                            p.pcxccant,
                            p.pcxccfan,
                            p.pcxccvvi,
                            p.pcxcccvi,
                            p.pcxcccomi,
                            p.pcxccdvven,
                            p.pcxccdvcom,
                            p.pcxcctrati,
                            p.pcxcciof,
                            p.pcxcccheq,
                            p.pcxctarifa,
                            p.pcxcccarta,
                            p.pcxchpro
                        FROM caiparam p
                    ) par ON par.pcxparam = GREATEST(d.depdepman::integer, 1)
            ) dep ON dep.deposito = l.lacdeposit
            LEFT JOIN (
                SELECT x.lacauxlanc,
                    x.lacauxseq,
                    x.laahistori,
                    x.laadescri,
                    x.laaccusto,
                    x.laaplanoc,
                    x.laared
                FROM lacaaux x
            ) aux ON aux.lacauxlanc = l.laclanca
            AND aux.lacauxseq = l.lacseq
            LEFT JOIN (
                SELECT j.lajlaclanc,
                    j.lajlacseq,
                    j.lajjred,
                    j.lajjccusto,
                    j.lajjplanoc,
                    j.lajdred,
                    j.lajdccusto,
                    j.lajdplanoc,
                    j.lajtred,
                    j.lajtccusto,
                    j.lajtplanoc,
                    j.lajmplanoc,
                    j.lajmred,
                    j.lajmccusto
                FROM lajuracr j
            ) jur ON jur.lajlaclanc = l.laclanca
            AND jur.lajlacseq = l.lacseq
            LEFT JOIN (
                SELECT d.duddata,
                    d.dudlanori,
                    d.dudbordero,
                    d.dudjuros,
                    d.dudtarifa,
                    d.dudiof,
                    d.dudprzmed,
                    d.dudtxjur,
                    d.dudprzdia
                FROM dupdes1 d
            ) dup ON dup.duddata = l.laclanca
            AND dup.dudlanori = l.lacseq
            LEFT JOIN (
                SELECT c.chdtalan,
                    c.chsqalan,
                    c.chvlrjuros,
                    c.chbordero,
                    c.chvltarifa,
                    c.chvlriof,
                    c.chprzmed,
                    c.chtxjuros,
                    c.chprzdia
                FROM chdesco c
            ) che ON che.chdtalan = l.laclanca
            AND che.chsqalan = l.lacseq
            LEFT JOIN (
                SELECT d.dbmdata,
                    d.dbmconta,
                    d.dbmseq,
                    d.dbmoriseq,
                    lad.lacbanco,
                    lad.lacccusto,
                    lad.lacplanoc
                FROM debmul d
                    LEFT JOIN (
                        SELECT a.laclanca,
                            a.lacseq,
                            a.lacbanco,
                            a.lacccusto,
                            a.lacplanoc
                        FROM lancai a
                    ) lad ON lad.laclanca = d.dbmdata
                    AND lad.lacseq = d.dbmoriseq
            ) deb ON deb.dbmdata = l.laclanca
            AND deb.dbmseq = l.lacseq
            LEFT JOIN (
                SELECT DISTINCT ON (recmul.rcmdata, recmul.rcmseq) recmul.rcmdata,
                    recmul.rcmconta,
                    recmul.rcmseq,
                    recmul.rcmoriseq,
                    lar.lacbanco,
                    lar.lacccusto,
                    lar.lacplanoc
                FROM recmul
                    LEFT JOIN (
                        SELECT chpredat.chdtlanca,
                            chpredat.chselanca
                        FROM chpredat
                    ) chp ON recmul.rcmdata = chp.chdtlanca
                    AND recmul.rcmoriseq = chp.chselanca
                    LEFT JOIN (
                        SELECT a.laclanca,
                            a.lacseq,
                            a.lacbanco,
                            a.lacccusto,
                            a.lacplanoc
                        FROM lancai a
                    ) lar ON lar.laclanca = recmul.rcmdata
                    AND lar.lacseq = recmul.rcmoriseq
                ORDER BY recmul.rcmdata DESC,
                    recmul.rcmseq DESC,
                    CASE
                        WHEN recmul.rcmdata = chp.chdtlanca
                        AND recmul.rcmoriseq = chp.chselanca THEN 2
                        ELSE 1
                    END
            ) rec ON rec.rcmdata = l.laclanca
            AND rec.rcmseq = l.lacseq
            LEFT JOIN (
                with chp as(
                    select CHDTLANCA,
                        CHSELANCA,
                        CHDTLACDES,
                        CHSELACDES,
                        CH2DTLACDE,
                        CH2SEQLAC
                    from chpredat
                    where ch2dtlacde is not null
                        and ch2seqlac is not null
                ),
                chp2 as (
                    select CHDTLANCA,
                        CHSELANCA,
                        CHDTLACDES,
                        CHSELACDES,
                        CH2DTLACDE,
                        CH2SEQLAC
                    from chpredat
                    where chdtlacdes is not null
                        and chselacdes is not null
                ),
                chp3 as (
                    select CHDTLANCA,
                        CHSELANCA,
                        CHDTLACDES,
                        CHSELACDES,
                        CH2DTLACDE,
                        CH2SEQLAC
                    from chpredat
                    where chdtlanca is not null
                        and chselanca is not null
                )
                SELECT DISTINCT ON (m.lcmdata, m.lcmseq) m.lcmdata,
                    m.lcmconta,
                    m.lcmseq,
                    m.lcmoriseq,
                    lam_1.lacbanco,
                    lam_1.lacccusto,
                    lam_1.lacplanoc
                FROM lacmul m
                    LEFT JOIN chp3 on (
                        chp3.chdtlanca = m.lcmdata
                        AND chp3.chselanca = m.lcmoriseq
                    )
                    LEFT JOIN chp2 on (
                        chp2.chdtlacdes = m.lcmdata
                        AND chp2.chselacdes = m.lcmoriseq
                    )
                    LEFT JOIN chp on (
                        chp.ch2dtlacde = m.lcmdata
                        AND chp.ch2seqlac = m.lcmoriseq
                    )
                    LEFT JOIN lancai lam_1 ON lam_1.laclanca = m.lcmdata
                    AND lam_1.lacseq = m.lcmoriseq
                ORDER BY m.lcmdata,
                    m.lcmseq,
                    CASE
                        WHEN m.lcmdata = chp3.chdtlanca
                        AND m.lcmoriseq = chp3.chselanca THEN 2
                        WHEN m.lcmdata = chp2.chdtlacdes
                        AND m.lcmoriseq = chp2.chselacdes THEN 3
                        WHEN m.lcmdata = chp.ch2dtlacde
                        AND m.lcmoriseq = chp.ch2seqlac THEN 3
                        ELSE 1
                    END
            ) lam ON lam.lcmdata = l.laclanca
            AND lam.lcmseq = l.lacseq
            LEFT JOIN (
                SELECT s.sacmdata,
                    s.sacmcont,
                    s.sacmseq,
                    s.sacmorseq,
                    las.lacbanco,
                    las.lacccusto,
                    las.lacplanoc
                FROM sacmul s
                    LEFT JOIN (
                        SELECT a.laclanca,
                            a.lacseq,
                            a.lacbanco,
                            a.lacccusto,
                            a.lacplanoc
                        FROM lancai a
                    ) las ON las.laclanca = s.sacmdata
                    AND las.lacseq = s.sacmorseq
            ) sac ON sac.sacmdata = l.laclanca
            AND sac.sacmseq = l.lacseq
            LEFT JOIN (
                SELECT d.duddata,
                    d.dudplanoc,
                    d.dudlandes,
                    d.dudlanori,
                    lau.lacbanco,
                    lau.lacccusto,
                    lau.lacplanoc
                FROM dupdes d
                    LEFT JOIN (
                        SELECT a.laclanca,
                            a.lacseq,
                            a.lacbanco,
                            a.lacccusto,
                            a.lacplanoc
                        FROM lancai a
                    ) lau ON lau.laclanca = d.duddata
                    AND lau.lacseq = d.dudlanori
            ) dud ON dud.duddata = l.laclanca
            AND dud.dudlandes = l.lacseq
            LEFT JOIN (
                SELECT i.intcontrol,
                    i.inttitulo,
                    i.intbenvio,
                    i.intbdtret,
                    i.intdtapr
                FROM titbanco i
            ) "int" ON "int".intcontrol::numeric = l.laccontrol::numeric
            AND "int".inttitulo = l.lactitulo
            LEFT JOIN (
                SELECT p.protcontro,
                    p.prottitulo,
                    p.protdata
                FROM protesto p
            ) pro ON pro.protcontro::numeric = l.laccontrol::numeric
            AND pro.prottitulo = l.lactitulo
            LEFT JOIN (
                SELECT t.controle,
                    t.titulo,
                    t.titcfco,
                    red.ctbcondepo,
                    red.ctbconclie,
                    red.ctbconforn,
                    rez.ctbconclie AS rez_ctbconclie,
                    rez.ctbconforn AS rez_ctbconforn
                FROM titulos t
                    LEFT JOIN (
                        SELECT r.ctbconempr,
                            r.ctbcondepo,
                            r.ctbconclie,
                            r.ctbconforn
                        FROM ctbconem r
                        WHERE r.ctbcondepo > 0
                    ) red ON red.ctbconempr = t.titcfco
                    LEFT JOIN (
                        SELECT z.ctbconempr,
                            z.ctbcondepo,
                            z.ctbconclie,
                            z.ctbconforn
                        FROM ctbconem z
                        WHERE z.ctbcondepo = 0
                    ) rez ON rez.ctbconempr = t.titcfco
            ) tit ON tit.controle = l.laccontrol
            AND tit.titulo = l.lactitulo
            AND (
                tit.ctbcondepo = l.lacdeposit
                OR tit.ctbcondepo IS NULL
            )
            LEFT JOIN (
                SELECT x.planoc,
                    x.plcproc
                FROM planoc x
            ) crd ON crd.planoc = l.lacplanoc
            LEFT JOIN (
                SELECT vlrante.vladata,
                    vlrante.vlaseq,
                    vlrante.vlaempresa
                FROM vlrante
            ) vlant ON vlant.vladata = l.laclanca
            AND vlant.vlaseq = l.lacseq
            left join (
                with chp as(
                    select CHDTLANCA,
                        CHSELANCA,
                        CHDTLACDES,
                        CHSELACDES,
                        CH2DTLACDE,
                        CH2SEQLAC
                    from chpredat
                    where ch2dtlacde is not null
                        and ch2seqlac is not null
                ),
                chp2 as (
                    select CHDTLANCA,
                        CHSELANCA,
                        CHDTLACDES,
                        CHSELACDES,
                        CH2DTLACDE,
                        CH2SEQLAC
                    from chpredat
                    where chdtlacdes is not null
                        and chselacdes is not null
                ),
                chp3 as (
                    select CHDTLANCA,
                        CHSELANCA,
                        CHDTLACDES,
                        CHSELACDES,
                        CH2DTLACDE,
                        CH2SEQLAC
                    from chpredat
                    where chdtlanca is not null
                        and chselanca is not null
                )
                select distinct on (lcmul.lcmdata, lcmul.lcmseq) lcmul.lcmdata,
                    lcmul.lcmseq,
                    lcmul.lcmoriseq,
                    lcai.lacccusto,
                    lcai.lacplanoc,
                    lcai.lactransa,
                    lcai.laclanca,
                    lcai.lacseq,
                    lcai.lacdeposit
                from lacmul lcmul
                    left join chp3 on (
                        chp3.chdtlanca = lcmul.lcmdata
                        and chp3.chselanca = lcmul.lcmoriseq
                    )
                    left join chp2 on (
                        chp2.chdtlacdes = lcmul.lcmdata
                        and chp2.chselacdes = lcmul.lcmoriseq
                    )
                    left join chp on (
                        chp.ch2dtlacde = lcmul.lcmdata
                        and chp.ch2seqlac = lcmul.lcmoriseq
                    )
                    left join lancai lcai on lcai.laclanca = lcmul.lcmdata
                    and lcai.lacseq = lcmul.lcmoriseq
                order by lcmul.lcmdata,
                    lcmul.lcmseq,
                    case
                        when lcmul.lcmdata = chp3.chdtlanca
                        and lcmul.lcmoriseq = chp3.chselanca then 2
                        when lcmul.lcmdata = chp2.chdtlacdes
                        and lcmul.lcmoriseq = chp2.chselacdes then 3
                        when lcmul.lcmdata = chp.ch2dtlacde
                        and lcmul.lcmoriseq = chp.ch2seqlac then 3
                        else 1
                    end
            ) lac on lac.lcmdata = l.laclanca
            and lac.lcmseq = l.lacseq
            left join (
                select count(*) as constalacmul,
                    lacmul.lcmoriseq,
                    lacmul.lcmdata
                from lacmul
                group by lacmul.lcmoriseq,
                    lacmul.lcmdata
            ) lcmul on lcmul.lcmoriseq = lac.lacseq
            and lcmul.lcmdata = lac.laclanca
            left join (
                select count(*) as constachquso1,
                    chquso.chusequso,
                    chquso.chudtuso
                from chquso
                where chquso.chusequen > 1
                group by chquso.chusequso,
                    chquso.chudtuso
            ) chq on chq.chusequso = lac.lacseq
            and chq.chudtuso = lac.laclanca
            left join (
                select prtipo1.prt1ccdeb,
                    prtipo1.prt1pcdeb,
                    prtipo1.prtdeposit
                from prtipo1
                where prtipo1.prtipo = 'CSF'::bpchar
            ) prt1 on prt1.prtdeposit = lac.lacdeposit
            left join (
                select planoc.planoc,
                    planoc.plcnome
                from planoc
            ) plcmul2 on plcmul2.planoc = prt1.prt1pcdeb
            left join (
                select prtipo1.prt1ccdeb,
                    prtipo1.prt1pcdeb,
                    prtipo1.prtdeposit
                from prtipo1
                where prtipo1.prtipo = 'CSF'::bpchar
                order by prtipo1.prtdeposit
            ) prt12 on prt12.prtdeposit = 0
            left join (
                select planoc.planoc,
                    planoc.plcnome
                from planoc
            ) plcmul3 on plcmul3.planoc = prt12.prt1pcdeb
            left join (
                select count(*) as constachquso2,
                    chquso.chusequso,
                    chquso.chudtuso
                from chquso
                group by chquso.chusequso,
                    chquso.chudtuso
            ) chq2 on chq2.chusequso = lac.lacseq
            and chq2.chudtuso = lac.laclanca
            left join (
                select length(btrim(caiparam.pcxpccheq::text)) as naopreenchidopcxpccheq,
                    caiparam.pcxparam
                from caiparam
            ) cprm on cprm.pcxparam = lac.lacdeposit
            left join (
                select n.planoc,
                    n.plcnome
                from planoc n
            ) plr on plr.planoc = dep.pcxpccaixa
        WHERE (
                l.laccaiban <> 'N'::bpchar
                OR l.lactransa = 'G'::bpchar
                OR l.lactransa = 'H'::bpchar
            )
            AND NOT (
                EXISTS (
                    SELECT 1
                    FROM debmul deb_1
                    WHERE deb_1.dbmdata = l.laclanca
                        AND deb_1.dbmoriseq = l.lacseq
                )
            )
            AND NOT (
                EXISTS (
                    SELECT 1
                    FROM recmul rec_1
                    WHERE rec_1.rcmdata = l.laclanca
                        AND rec_1.rcmoriseq = l.lacseq
                )
            )
            AND NOT (
                EXISTS (
                    SELECT 1
                    FROM lacmul lam_1
                    WHERE lam_1.lcmdata = l.laclanca
                        AND lam_1.lcmoriseq = l.lacseq
                )
            )
            AND NOT (
                EXISTS (
                    SELECT 1
                    FROM sacmul sac_1
                    WHERE sac_1.sacmdata = l.laclanca
                        AND sac_1.sacmorseq = l.lacseq
                )
            )
            AND NOT (
                EXISTS (
                    SELECT 1
                    FROM dupdes dup_1
                    WHERE dup_1.duddata = l.laclanca
                        AND dup_1.dudlanori = l.lacseq
                )
            )
            AND NOT (
                EXISTS (
                    SELECT 1
                    FROM compcart car
                    WHERE car.compdata = l.laclanca
                        AND car.compentban = l.lacseq
                )
            )
    ) fin
    LEFT JOIN (
        SELECT c.planoc,
            c.plcproc
        FROM planoc c
    ) plc ON plc.planoc::text = fin.financeiro_conta_credito_codigo_fk
    LEFT JOIN (
        SELECT d.planoc,
            d.plcproc
        FROM planoc d
    ) pld ON pld.planoc::text = fin.financeiro_conta_debito_codigo_fk
    LEFT JOIN (
        SELECT c.planoc,
            c.plcproc
        FROM planoc c
    ) pjc ON pjc.planoc::text = fin.financeiro_conta_juros_credito_codigo_fk
    LEFT JOIN (
        SELECT d.planoc,
            d.plcproc
        FROM planoc d
    ) pjd ON pjd.planoc::text = fin.financeiro_conta_juros_debito_codigo_fk
    LEFT JOIN (
        SELECT c.planoc,
            c.plcproc
        FROM planoc c
    ) pdc ON pdc.planoc::text = fin.financeiro_conta_desconto_credito_codigo_fk
    LEFT JOIN (
        SELECT d.planoc,
            d.plcproc
        FROM planoc d
    ) pdd ON pdd.planoc::text = fin.financeiro_conta_desconto_debito_codigo_fk
    LEFT JOIN (
        SELECT c.planoc,
            c.plcproc
        FROM planoc c
    ) ptc ON ptc.planoc::text = fin.financeiro_conta_tarifa_credito_codigo_fk
    LEFT JOIN (
        SELECT d.planoc,
            d.plcproc
        FROM planoc d
    ) ptd ON ptd.planoc::text = fin.financeiro_conta_tarifa_debito_codigo_fk
    LEFT JOIN (
        SELECT d.planoc,
            d.plcproc
        FROM planoc d
    ) pid ON pid.planoc::text = fin.financeiro_conta_iof_debito_codigo_fk
    LEFT JOIN (
        SELECT tju.titrjcontr AS financeiro_titulo_recuperacao_judicial_controle_fk,
            tju.titrjnumti
        FROM titrjudi tju
    ) jur ON jur.financeiro_titulo_recuperacao_judicial_controle_fk = fin.financeiro_titulo_controle_fk
    AND jur.titrjnumti = fin.financeiro_titulo_codigo_fk
ORDER BY fin.financeiro_data_lancamento,
    fin.financeiro_sequencia;
ALTER TABLE pw_financeiro OWNER TO postgres;