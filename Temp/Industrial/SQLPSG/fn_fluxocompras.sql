-- Function: fn_fluxocompras(date, date, character, integer)

-- DROP FUNCTION fn_fluxocompras(date, date, character, integer);

CREATE OR REPLACE FUNCTION fn_fluxocompras(pdataini date, pdatafim date, pusuario character, pdeposito integer)
  RETURNS void AS
$BODY$ BEGIN -- limpa temporário para compras
    -- está fazendo fora da função - OS 2792416
    -- delete from umfluxo where umfluusu = pusuario and umorigem ='P.CMP.';
    -- grava informações no temporário
INSERT INTO UMFLUXO (
        UMFLUUSU,
        UMFLUDATA,
        UMFLUTIPO,
        UMORIGEM,
        UMBANCO,
        UMCODIGO,
        UMSEQUEN,
        UMHISTORIC,
        UMVALORE,
        UMVALORS,
        UMBANOME,
        UMMODCOB
    )
SELECT PUSUARIO,
    Y.DATACOM,
    'I',
    'P.CMP.',
    REPEAT(' ', 3),
    Y.COMPRA::VARCHAR,
    Y.PARCELA,
    Y.EMPRESA,
    0.00,
    Y.VALOR,
    REPEAT(' ', 20),
    Y.MODALIDADE
FROM (
        SELECT X.DATACOM,
            X.COMPRA,
            X.PARCELA,
            X.EMPRESA,
            X.MODALIDADE,
            SUM(
                ROUND(
                    CASE
                        WHEN X.TIPO = 'V' THEN (
                            (
                                X.VLRCTB - CASE
                                    WHEN X.LINHA = 1 THEN X.DESCONTO
                                    ELSE 0
                                END
                            ) + (X.VLRCOMIPI * X.DESPESA / 100)
                        ) * (X.PCT / 100)::NUMERIC(15, 8)
                        ELSE X.VLRCTB - CASE
                            WHEN X.LINHA = 1 THEN X.DESCONTO
                            ELSE 0
                        END + (X.VLRCOMIPI * X.DESPESA / 100)::NUMERIC(15, 8)
                    END,
                    6
                ) + ROUND(
                    CASE
                        WHEN X.PERFRETE <> 0
                        AND X.RESPONSAVEL = 'F' THEN CASE
                            WHEN X.TIPO = 'V' THEN (
                                (
                                    X.VLRCTB - CASE
                                        WHEN X.LINHA = 1 THEN X.DESCONTO
                                        ELSE 0
                                    END
                                ) + (X.VLRSEMIPI * X.DESPESA / 100)
                            ) * (X.PCT / 100)::NUMERIC(15, 8)
                            ELSE X.VLRCTB - CASE
                                WHEN X.LINHA = 1 THEN X.DESCONTO
                                ELSE 0
                            END + (X.VLRSEMIPI * X.DESPESA / 100)::NUMERIC(15, 8)
                        END * X.PERFRETE / 100
                        WHEN X.VLRFRETE <> 0
                        AND X.RESPONSAVEL = 'F' THEN CASE
                            WHEN (X.TIPO = 'V') THEN (
                                (
                                    X.VLRCTB - CASE
                                        WHEN X.LINHA = 1 THEN X.DESCONTO
                                        ELSE 0
                                    END
                                ) + (X.VLRSEMIPI * X.DESPESA / 100)
                            ) * (X.PCT / 100)::NUMERIC(15, 8)
                            ELSE X.VLRCTB - CASE
                                WHEN X.LINHA = 1 THEN X.DESCONTO
                                ELSE 0
                            END + (X.VLRSEMIPI * X.DESPESA / 100) + ROUND(X.VLRSEMIPI * (X.DESPESA / 100), 6)
                        END * X.VLRFRETE / X.VLRTOTAL
                        ELSE 0
                    END,
                    6
                ) + CASE
                    WHEN X.PARCELA = '1'
                    AND X.CONDIPI = 'S'
                    AND X.CONDST = 'N'
                    AND X.LINHA = 1 THEN X.VLRIPI
                    WHEN X.PARCELA = '1'
                    AND X.CONDIPI = 'N'
                    AND X.CONDST = 'S' THEN X.VLRICMST
                    WHEN X.PARCELA = '1'
                    AND X.CONDIPI = 'S'
                    AND X.CONDST = 'S'
                    AND X.LINHA = 1 THEN X.VLRIPI + X.VLRST
                    WHEN X.PARCELA = '1'
                    AND X.CONDIPI = 'N'
                    AND X.CONDST = 'N' THEN 0
                    ELSE 0
                END
            )::NUMERIC(15, 2) AS VALOR
        FROM (
                SELECT CASE
                        WHEN M.PCXDTBASE = 'I' THEN CASE
                            WHEN (V.TIPO = 'V') THEN I.CMPPREV + V.DIAS
                            ELSE CASE
                                WHEN (V.MES = 'A') THEN I.CMPPREV
                                ELSE I.CMPPREV + 30
                            END
                        END
                        ELSE CASE
                            WHEN (V.TIPO = 'V') THEN C.COMFATUR + V.DIAS
                            ELSE CASE
                                WHEN (V.MES = 'A') THEN C.COMFATUR
                                ELSE C.COMFATUR + 30
                            END
                        END
                    END AS DATACOM,
                    -- Valor sem IPI
                    ROUND(
                        (
                            I.CMPQUANTI - CASE
                                WHEN VAL.PRIQUANTI > 0 THEN VAL.PRIQUANTI
                                ELSE 0
                            END - I.COMQATEND
                        ) * I.CMPUNITA,
                        6
                    ) AS VLRSEMIPI,
                    -- Valor contábil (parcela)
                    ROUND(
                        (
                            (
                                I.CMPQUANTI - CASE
                                    WHEN VAL.PRIQUANTI > 0 THEN VAL.PRIQUANTI
                                    ELSE 0
                                END - I.COMQATEND
                            ) * I.CMPUNITA
                        ) + CASE
                            WHEN V.CONDIPI = 'N' THEN -- ipi rateado nas parcelas
                            ROUND(
                                (
                                    (
                                        I.CMPQUANTI - CASE
                                            WHEN VAL.PRIQUANTI > 0 THEN VAL.PRIQUANTI
                                            ELSE 0
                                        END - I.COMQATEND
                                    ) * I.CMPUNITA
                                ) * (I.CMPIPI / 100),
                                6
                            )
                            ELSE 0
                        END + CASE
                            WHEN V.CONDST = 'N' THEN -- st rateado nas parcelas
                            ROUND(
                                (
                                    (
                                        I.CMPQUANTI - CASE
                                            WHEN VAL.PRIQUANTI > 0 THEN VAL.PRIQUANTI
                                            ELSE 0
                                        END - I.COMQATEND
                                    ) * I.CMPVLICMST
                                ) / I.CMPQUANTI
                            )
                            ELSE 0
                        END,
                        6
                    ) AS VLRCTB,
                    -- Valor com IPI
                    ROUND(
                        (
                            (
                                I.CMPQUANTI - CASE
                                    WHEN VAL.PRIQUANTI > 0 THEN VAL.PRIQUANTI
                                    ELSE 0
                                END - I.COMQATEND
                            ) * I.CMPUNITA
                        ) + ROUND(
                            (
                                (
                                    I.CMPQUANTI - CASE
                                        WHEN VAL.PRIQUANTI > 0 THEN VAL.PRIQUANTI
                                        ELSE 0
                                    END - I.COMQATEND
                                ) * I.CMPUNITA
                            ) * (I.CMPIPI / 100),
                            6
                        ) + ROUND(
                            (
                                (
                                    I.CMPQUANTI - CASE
                                        WHEN VAL.PRIQUANTI > 0 THEN VAL.PRIQUANTI
                                        ELSE 0
                                    END - I.COMQATEND
                                ) * I.CMPVLICMST
                            ) / I.CMPQUANTI
                        ),
                        6
                    ) AS VLRCOMIPI,
                    I.CMPTOTPRO AS VLRPRODUTOS,
                    I.CMPVLICMST AS VLRICMST,
                    C.COMVLDESCO AS DESCONTO,
                    C.COMDESPESA AS DESPESA,
                    C.COMPERFRET AS PERFRETE,
                    C.COMVLFRETE AS VLRFRETE,
                    TOT.CMPTOTAL AS VLRTOTAL,
                    TOT.CMPTOTIPI AS VLRIPI,
                    TOT.CMPTOTST AS VLRST,
                    C.COMRESPONS AS RESPONSAVEL,
                    C.COMMODC AS MODALIDADE,
                    I.COMPRA,
                    V.PARCELA::INT,
                    'PED.COMPRA ' || SUBSTR(EMP.EMPNOME, 1, 24) AS EMPRESA,
                    V.TIPO,
                    V.PCT AS PCT,
                    V.CONDIPI,
                    V.CONDST,
                    RANK() OVER(
                        PARTITION BY I.COMPRA
                        ORDER BY I.CMPSEQ
                    ) AS LINHA
                FROM COMPRA3 I
                    LEFT JOIN (
                        SELECT T.PRICOMPRA,
                            T.PRIPRODUTO,
                            T.PRICMPSEQ,
                            SUM(T.PRIVLTOTAL) AS PRIVLTOTAL,
                            SUM(T.PRIQUANTI) AS PRIQUANTI
                        FROM TOQMOVI T,
                            DOCTOS D,
                            OPERA O
                        WHERE D.CONTROLE = T.ITECONTROL
                            AND T.OPERACAO = O.OPERACAO
                            AND NOT (
                                D.NOTDTDIGIT IS NULL
                                OR D.NOTDTDIGIT = '0001-01-01'
                            )
                            AND NOT SUBSTR(D.NOTOBSFISC, 1, 10) = 'NF ANULADA'
                            AND O.OPECOM = 'S'
                        GROUP BY T.PRICOMPRA,
                            T.PRIPRODUTO,
                            T.PRICMPSEQ
                    ) AS VAL ON (
                        VAL.PRICOMPRA = I.COMPRA
                        AND VAL.PRIPRODUTO = I.PRODUTO
                        AND VAL.PRICMPSEQ = I.CMPSEQ
                    )
                    LEFT JOIN (
                        SELECT X.COMPRA,
                            SUM(X.CMPQUANTI) AS CMPQUANTI,
                            SUM(
                                ROUND(
                                    (
                                        (X.CMPQUANTI - X.COMQATEND) * X.CMPUNITA
                                    ) + ROUND(
                                        (
                                            (
                                                X.CMPQUANTI - X.COMQATEND
                                            ) * X.CMPUNITA
                                        ) * (X.CMPIPI / 100),
                                        8
                                    ),
                                    8
                                ) + X.CMPVLICMST
                            ) AS CMPTOTAL,
                            SUM(
                                ROUND(
                                    (
                                        (X.CMPQUANTI - X.COMQATEND) * X.CMPUNITA
                                    ) + ROUND(
                                        (
                                            (
                                                X.CMPQUANTI - X.COMQATEND
                                            ) * X.CMPUNITA
                                        ) * (X.CMPIPI / 100),
                                        8
                                    ),
                                    8
                                ) - X.CMPTOTPRO
                            ) AS CMPTOTIPI,
                            SUM(X.CMPVLICMST) AS CMPTOTST
                        FROM COMPRA3 X
                        WHERE (
                                X.CMPATED IS NULL
                                OR X.CMPATED = '0001-01-01'
                            )
                        GROUP BY X.COMPRA
                    ) AS TOT ON (TOT.COMPRA = I.COMPRA),
                    VW_CONDPAG_PARAM V,
                    CAIPARAM M,
                    COMPRA C
                    LEFT JOIN (
                        SELECT E.EMPRESA,
                            E.EMPNOME
                        FROM EMPRESA E
                    ) AS EMP ON (EMP.EMPRESA = C.EMPRESA)
                    LEFT JOIN (
                        SELECT B.MODCOBRA,
                            B.MODFLUXO
                        FROM MODCOBRA B
                    ) AS MOD ON (MOD.MODCOBRA = C.COMMODC)
                WHERE (
                        I.CMPATED IS NULL
                        OR I.CMPATED = '0001-01-01'
                    )
                    AND I.CMPQUANTI > 0
                    AND (
                        (C.DEPOSITO = PDEPOSITO)
                        OR PDEPOSITO = 0
                    )
                    AND (
                        C.COMAPROVA <> 'NA'
                        AND C.COMAPROVA <> 'CA'
                    )
                    AND C.COMPRA = I.COMPRA
                    AND M.PCXPARAM = 1
                    AND (
                        C.CONDICAO IS NOT NULL
                        AND LENGTH(TRIM(C.CONDICAO)) > 0
                    )
                    AND C.CONDICAO = V.CONDICAO
                    AND MOD.MODFLUXO <> 'N'
            ) AS X
        GROUP BY X.DATACOM,
            X.COMPRA,
            X.PARCELA,
            X.EMPRESA,
            X.MODALIDADE
        HAVING X.DATACOM BETWEEN PDATAINI AND PDATAFIM
    ) AS Y
WHERE Y.VALOR > 0
UNION ALL
SELECT DISTINCT PUSUARIO,
    PRE.COMPDATA AS DATA,
    'I',
    'P.CMP.',
    REPEAT(' ', 3),
    C.COMPRA::VARCHAR,
    PRE.COMPNUM::INT,
    'PED.COMPRA ' || SUBSTR(EMP.EMPNOME, 1, 24),
    0.00,
    (
        CASE
            WHEN (
                (
                    CASE
                        /*Caso o pedido ainda tenha saldo por atender*/
                        WHEN (PercPrevi.FatorDecrescimoSaldo > 0) then (PRE.COMPVALOR * PercPrevi.FatorDecrescimoSaldo)
                        ELSE 0
                    END
                )::NUMERIC(15, 2) - (
                    CASE
                        WHEN ANT.VLANTECIPA IS NOT NULL THEN ANT.VLANTECIPA
                        ELSE 0
                    END
                ) < 0
            ) THEN 0
            ELSE (
                (
                    CASE
                        /*Caso o pedido ainda tenha saldo por atender*/
                        WHEN (PercPrevi.FatorDecrescimoSaldo > 0) THEN (PRE.COMPVALOR * PercPrevi.FatorDecrescimoSaldo)
                        ELSE 0
                    END
                )::NUMERIC(15, 2) - (
                    CASE
                        WHEN ANT.VLANTECIPA IS NOT NULL THEN ANT.VLANTECIPA
                        ELSE 0
                    END
                )
            )
        END
    ) AS VALOR,
    REPEAT(' ', 20),
    C.COMMODC
from COMPRA3 I,
    COMPRA C
    left join (
        select B.MODCOBRA,
            B.MODFLUXO
        from MODCOBRA B
    ) as mod on (MOD.MODCOBRA = C.COMMODC)
    left join (
        select E.EMPRESA,
            E.EMPNOME
        from EMPRESA E
    ) as EMP on (EMP.EMPRESA = C.EMPRESA)
    left join (
        select Q.COMPRA,
            Q.COMPDATA,
            Q.COMPVALOR,
            Q.COMPNUM
        from PREVICOM Q            
    ) as PRE on (PRE.COMPRA = C.COMPRA)
    left join (
        select V.VLACOMPRA,
            V.VLACOMNUM,
            SUM(V.VLANTECIPA) as VLANTECIPA
        from VLRANTE V
        group by V.VLACOMPRA,
            V.VLACOMNUM
    ) as ANT on (
        ANT.VLACOMPRA = C.COMPRA
        and ANT.VLACOMNUM = PRE.COMPNUM
    )
    left join (
        select T.PRICOMPRA,
            SUM(T.PRIVLTOTAL) as PRIVLTOTAL,
            SUM(T.PRIQUANTI) as PRIQUANTI
        from TOQMOVI T,
            DOCTOS D,
            OPERA O
        where D.CONTROLE = T.ITECONTROL
            and T.OPERACAO = O.OPERACAO
            and not (
                D.NOTDTDIGIT is null
                or D.NOTDTDIGIT = '0001-01-01'
            )
            and not SUBSTR(D.NOTOBSFISC, 1, 10) = 'NF ANULADA'
            and O.OPECOM = 'S'
        group by T.PRICOMPRA
    ) as VAL on (VAL.PRICOMPRA = C.COMPRA)
    left join (
        select I.COMPRA,
            SUM(I.CMPQUANTI) as CMPQUANTI,
            SUM(
                ROUND(
                    ((I.CMPQUANTI - I.COMQATEND) * I.CMPUNITA) + ROUND(
                        (
                            (I.CMPQUANTI - I.COMQATEND) * I.CMPUNITA
                        ) * (I.CMPIPI / 100),
                        8
                    ),
                    8
                ) + 0
            ) as CMPTOTAL
        from COMPRA3 I
        where (
                I.CMPATED is null
                or I.CMPATED = '0001-01-01'
            )
        group by I.COMPRA
    ) as ITE on (ITE.COMPRA = C.COMPRA)
    left join (
        select compra,
            case
                when sum(cmptotal) <= 0 then 0
                else round(sum(valorsaldoitem) / sum(cmptotal), 4)
            end as FatorDecrescimoSaldo
        from (
                select compra,
                    cmpseq,
                    cmptotal,
                    (cmptotal / cmpquanti) *(
                        round(
                            cmpquanti -(coalesce(priquanti, 0) + comqatend),
                            2
                        )
                    ) as ValorSaldoItem
                from (
                        select T.PRICOMPRA,
                            T.PRIPRODUTO,
                            PRICMPSEQ,
                            SUM(T.PRIQUANTI) as PRIQUANTI
                        from TOQMOVI T,
                            DOCTOS D,
                            OPERA O
                        where D.CONTROLE = T.ITECONTROL
                            and T.OPERACAO = O.OPERACAO
                            and not (
                                D.NOTDTDIGIT is null
                                or D.NOTDTDIGIT = '0001-01-01'
                            )
                            and not SUBSTR(D.NOTOBSFISC, 1, 10) = 'NF ANULADA '
                            and O.OPECOM = 'S '
                        group by T.PRICOMPRA,
                            T.PRIPRODUTO,
                            T.PRICMPSEQ
                    ) as sub1
                    right join (
                        select compra,
                            cmpseq,
                            produto,
                            cmpquanti,
                            comqatend,
                            case
                                when cmpbcipi = 0 then round(
                                    (
                                        CMPTOTPRO + round(CMPTOTPRO * (CMPIPI / 100), 2) + CMPVLICMST
                                    ),
                                    2
                                )
                                else round(
                                    CMPTOTPRO + round(CMPBCIPI * (CMPIPI / 100), 2) + CMPVLICMST,
                                    2
                                )
                            end as cmptotal
                        from compra3
                        where cmpquanti > 0
                            and cmptotpro > 0
                    ) as sub2 on sub1.pricompra = sub2.compra
                    and (
                        sub1.pricmpseq = sub2.cmpseq
                        or sub1.pricmpseq < 1
                    )
                    and sub1.priproduto = sub2.produto
            ) as sub3
        group by compra
    ) as PercPrevi on PercPrevi.compra = C.COMPRA
where (
        C.COMAPROVA <> 'NA'
        and C.COMAPROVA <> 'CA'
    )
    and I.CMPQUANTI > 0
    and (
        (C.DEPOSITO = PDEPOSITO)
        or PDEPOSITO = 0
    )
    and (C.COMPRA = I.COMPRA)
    and (
        I.CMPATED is null
        or I.CMPATED = '0001-01-01'
    )
    and (
        C.CONDICAO is null
        or LENGTH(TRIM(C.CONDICAO)) = 0
    )
    and (MOD.MODFLUXO <> 'N')
    and (
        (
            case
                when (
                    (ITE.CMPTOTAL / ITE.CMPQUANTI) * (ITE.CMPQUANTI - VAL.PRIQUANTI)
                ) > 0 then PRE.COMPVALOR / 100 * (
                    (
                        (ITE.CMPTOTAL / ITE.CMPQUANTI) * (ITE.CMPQUANTI - VAL.PRIQUANTI)
                    ) * 100
                ) / ITE.CMPTOTAL
                else PRE.COMPVALOR
            end
        )::numeric(15, 2) - (
            case
                when ANT.VLANTECIPA is not null then ANT.VLANTECIPA
                else 0
            end
        )
    ) > 0
    and PRE.COMPDATA between PDATAINI and PDATAFIM
UNION ALL
SELECT PUSUARIO,
    X.DATA,
    'I',
    'P.CMP.',
    REPEAT(' ', 3),
    X.COMPRA,
    1,
    X.EMPNOME,
    0.00,
    CASE
        WHEN (
            (X.CMPTOTAL / X.CMPQUANTI) * (X.CMPQUANTI - X.PRIQUANTI)
        ) > 0 THEN X.VALOR / 100 * (
            (
                (X.CMPTOTAL / X.CMPQUANTI) * (X.CMPQUANTI - X.PRIQUANTI)
            ) * 100
        ) / X.CMPTOTAL
        ELSE X.VALOR
    END AS VALOR,
    REPEAT(' ', 20),
    X.COMMODC
FROM (
        SELECT DISTINCT CASE
                WHEN C.COMDTFRETE IS NOT NULL
                AND C.COMDTFRETE <> '0001-01-01' THEN C.COMDTFRETE
                WHEN (
                    C.COMDTFRETE IS NULL
                    OR C.COMDTFRETE = '0001-01-01'
                )
                AND P.PCXDTBASE = 'I' THEN I.CMPPREV
                WHEN (
                    C.COMDTFRETE IS NULL
                    OR C.COMDTFRETE = '0001-01-01'
                )
                AND P.PCXDTBASE <> 'I' THEN C.COMFATUR
            END AS DATA,
            C.COMPRA::VARCHAR || 'FRETE' AS COMPRA,
            'FRETE PED.CMP.' || SUBSTR(EMP.EMPNOME, 1, 20) AS EMPNOME,
            CASE
                WHEN C.COMVLFRETE <> 0 THEN ROUND(C.COMVLFRETE * (100 / 100), 2)
                ELSE ROUND(
                    (ROUND(C.COMVLFINAL * (C.COMPERFRET / 100), 2)) * (100 / 100),
                    2
                )
            END AS VALOR,
            C.COMMODC,
            ITE.CMPTOTAL,
            ITE.CMPQUANTI,
            VAL.PRIQUANTI
        FROM CAIPARAM P,
            COMPRA3 I,
            COMPRA C
            LEFT JOIN (
                SELECT B.MODCOBRA,
                    B.MODFLUXO
                FROM MODCOBRA B
            ) AS MOD ON (MOD.MODCOBRA = C.COMMODC)
            LEFT JOIN (
                SELECT E.EMPRESA,
                    E.EMPNOME
                FROM EMPRESA E
            ) AS EMP ON (EMP.EMPRESA = C.COMTRANSPO)
            LEFT JOIN (
                SELECT Q.COMPRA,
                    Q.COMPDATA,
                    Q.COMPVALOR,
                    Q.COMPNUM
                FROM PREVICOM Q
            ) AS PRE ON (PRE.COMPRA = C.COMPRA)
            LEFT JOIN (
                SELECT T.PRICOMPRA,
                    SUM(T.PRIVLTOTAL) AS PRIVLTOTAL,
                    SUM(T.PRIQUANTI) AS PRIQUANTI
                FROM TOQMOVI T,
                    DOCTOS D,
                    OPERA O
                WHERE D.CONTROLE = T.ITECONTROL
                    AND T.OPERACAO = O.OPERACAO
                    AND NOT (
                        D.NOTDTDIGIT IS NULL
                        OR D.NOTDTDIGIT = '0001-01-01'
                    )
                    AND NOT SUBSTR(D.NOTOBSFISC, 1, 10) = 'NF ANULADA'
                    AND O.OPECOM = 'S'
                GROUP BY T.PRICOMPRA
            ) AS VAL ON (VAL.PRICOMPRA = C.COMPRA)
            LEFT JOIN (
                SELECT I.COMPRA,
                    SUM(I.CMPQUANTI) AS CMPQUANTI,
                    SUM(
                        ROUND(
                            (
                                (I.CMPQUANTI - I.COMQATEND) * I.CMPUNITA
                            ) + ROUND(
                                (
                                    (I.CMPQUANTI - I.COMQATEND) * I.CMPUNITA
                                ) * (I.CMPIPI / 100),
                                8
                            ),
                            8
                        ) + 0
                    ) AS CMPTOTAL
                FROM COMPRA3 I
                WHERE (
                        I.CMPATED IS NULL
                        OR I.CMPATED = '0001-01-01'
                    )
                GROUP BY I.COMPRA
            ) AS ITE ON (ITE.COMPRA = C.COMPRA)
        WHERE P.PCXPARAM = 1
            AND (
                C.COMAPROVA <> 'NA'
                AND C.COMAPROVA <> 'CA'
            )
            AND I.CMPQUANTI > 0
            AND (
                (C.DEPOSITO = PDEPOSITO)
                OR PDEPOSITO = 0
            )
            AND (C.COMPRA = I.COMPRA)
            AND (
                I.CMPATED IS NULL
                OR I.CMPATED = '0001-01-01'
            )
            AND (MOD.MODFLUXO <> 'N')
            AND C.COMRESPONS = 'T'
    ) AS X
WHERE X.VALOR > 0
    AND X.DATA BETWEEN PDATAINI AND PDATAFIM;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_fluxocompras(date, date, character, integer)
  OWNER TO postgres;
