--drop function fn_apura_exportacao_contabilidade_vendas(int, date, date, text)
CREATE OR REPLACE FUNCTION fn_apura_exportacao_contabilidade_vendas(
        pdeposito int,
        dataInicial date,
        dataFinal date,
        usuario text
    ) RETURNS void as $BODY$ BEGIN

    DROP TABLE IF EXISTS valor_inss_n_INTCTB_PINTVLRINSS;
CREATE TEMP TABLE valor_inss_n_INTCTB_PINTVLRINSS AS (
    select t.ITECONTROL,
        sum(
            CASE
                WHEN OPEIRRF = 'S' THEN PRIVLTOTAL
                ELSE 0
            end
        ) vlrtotirrf,
        sum(
            CASE
                WHEN OPEISSQN = 'S'
                and OPECINSS = 'S'
                and GRUPO = 999 THEN PRIVLTOTAL
                ELSE 0
            end
        ) as vlrtotinss,
        sum(
            CASE
                WHEN OPEISSQN = 'S'
                and OPECISSQN = 'S'
                and GRUPO = 999 THEN PRIVLTOTAL
                ELSE 0
            end
        ) as vlrtotissqn
    from opera o
        left join toqmovi t on o.operacao = t.operacao
        left join produto p on p.produto = t.priproduto
        AND grupo = 999
    WHERE OPECTB = 'S'
        AND (
            OPEIRRF = 'S'
            OR (
                OPEISSQN = 'S'
                and GRUPO = 999
                and (
                    OPECINSS = 'S'
                    OR OPECISSQN = 'S'
                )
            )
        )
    group by t.ITECONTROL,
        opeirrf
);
ANALYSE valor_inss_n_INTCTB_PINTVLRINSS;
DROP TABLE IF EXISTS temp_apuracao_vendas;
CREATE TABLE temp_apuracao_vendas AS 
with parametro_fechamento_livros_fiscais as (
    select case
            when length(trim(pffosimple)) > 0 then pffosimple
            else 'N'
        end as esimples,
        pffdescont as abatedesc,
        *
    from parfecfi p
    where pffparam = 1
        /*Sempre eh apenas 1 registro com codigo 1? Pode nao existir nenhum registro e ter que considerar algum valor default?.*/
        --order by pffparam desc
    limit 1
), parametros_deposito as (
    select case
            when pdeposito NOT IN (0, 99) then depsimples
            else ''
        end as depsimples,
        case
            when pdeposito <> 0
            and pdeposito <> 99 then depcrt
            else ''
        end as depcrt
    from deposito
    where deposito = pdeposito --order by deposito desc
    limit 1
), so_o_que_precisa_do_pesimples_simplificado AS (
    select CASE
            -- Se o CRT nao for 2 deve o multiplicador de ICMS sera 0 pois o imposto sera deve ser desconsiderado (descrever por que)
            when parametros_deposito.depcrt <> '2'
            AND (
                --Deposito preenchido e esta configurado como simples (o que signifca deposito simples?)
                (
                    pdeposito NOT IN (0, 99)
                    AND parametros_deposito.depsimples = 'S'
                )
                OR --OU Deposito em branco e os parametros de livros ficais configurado para considerar como simples (o que signifca deposito simples?)
                (
                    pdeposito in (0, 99)
                    AND parametro_fechamento_livros_fiscais.esimples = 'S'
                )
            ) THEN 0
            ELSE 1
        end as multicms
        /*multiplicador de icms, para considerar ou nao o imposto*/
,
        parametros_deposito.depcrt as depcrt,
        abatedesc
    from parametro_fechamento_livros_fiscais,
        parametros_deposito
),
/*Estou partindo do principio que sempre retornara apenas um registro correspondente - Vinicius (Ricardo: Acho que nao esta correto o limit 1, talvez devesse ser distinct on... ) */
retorna_icms_origem as (
    --alterado tipo do controle da devcompra de numeric(10) para int8 
    --
    --
    --EXPLAIN (ANALYZE, buffers) 
    --    select
    --    *
    --     --,(SELECT PRIQUANTI FROM TOQMOVI WHERE ITECONTROL = DCOCONORI and PRISEQUEN = DCOSEQORI) AS quantidadeOrigem
    --    from (SELECT dcocontrol, dcoproduto, dcosequen, dcoconori::bigint, dcoseqori FROM public.devcompr) devcompr
    --        left join (SELECT ITECONTROL, PRISEQUEN, PRIQUANTI FROM toqmovi) t on ITECONTROL = DCOCONORI and PRISEQUEN = DCOSEQORI
    --        --left join toqsimpl on toscontrol = dcoconori and tossequen = dcoseqori
    --    
    select dcocontrol,
        dcosequen,
        max(tosvlcred) AS tosvlcred,
        max(PRIQUANTI) as quantidadeOrigem --,
        --,count(*) AS se_for_maior_que_um_opde_talvez_ser_erro
    from devcompr
        left join toqsimpl on toscontrol = dcoconori
        and tossequen = dcoseqori
        left join toqmovi t on ITECONTROL = DCOCONORI
        and PRISEQUEN = DCOSEQORI --#PERIGO: FILTRO DE TESTE PERFORMANCE TEM O MELHOR RESULTADO, MAS PRECISAMOS CONEFRIR QUAL DATA DE DCOCONTROL QUE PODE SER FILTRADA!! POIS PRIDATA NaO DEVE SER A CORRETA POIS e REFERENCIA DE ORIGEM QUE PODE ESTAR EM OUTRA DATA.
        --WHERE (PRIDATA BETWEEN (dataInicial::DATE - INTERVAL '1 MONTHS') AND dataFinal::DATE + INTERVAL '1 MONTHS')
    GROUP BY dcocontrol,
        dcosequen --SELECT * FROM TOQMOVI ORDER BY PRIDATA DESC LIMIT 1
        --limit 1 # TODO: ERRO? VALIDAR, POIS ESTE LIMIT 1 So VAI TRAZER 1 REGISTRO PARA TODO O DATASET E NaO 1 PARA CADA CONTROLE/SEQ. (Base que estamos testando so tem 2 registros nesta tabela, precisamos considerar performance)
),
vlr_pis_st_e_cofins_st_STPISCOF as (
    select stpicont,
        stpiseq,
        case
            when STPIVLRPIS > 0 then STPIVLRPIS
            when STPI2VLRPI > 0 then STPI2VLRPI
            ELSE 0::NUMERIC
        end as vlrpisst,
        case
            when STPIVLRCOF > 0 then STPIVLRCOF
            when STPI2VLRCO > 0 then STPI2VLRCO
            ELSE 0::NUMERIC
        end as vlrcofst
    from STPISCOF
),
/*Ricardo: Realizado JOIN das 3 CTES.
 * TODO: Verificar se os valores estao corretos. (para Patrimar o ano de 2023 fechou 100%, docepao ha controles para serem analisados)*/
--valor_inss_n_INTCTB_PINTVLRINSS AS (
--    select 
--        t.ITECONTROL,
--        sum(CASE WHEN OPEIRRF = 'S' THEN PRIVLTOTAL ELSE 0 end) vlrtotirrf,
--        sum(CASE WHEN OPEISSQN = 'S' and OPECINSS = 'S' and GRUPO = 999 THEN PRIVLTOTAL ELSE 0 end) as vlrtotinss,
--        sum(CASE WHEN OPEISSQN = 'S' and OPECISSQN = 'S' and GRUPO = 999 THEN PRIVLTOTAL ELSE 0 end) as vlrtotissqn
--    from opera o
--    left join toqmovi t on o.operacao = t.operacao
--    left join produto p on p.produto = t.priproduto
--    WHERE OPECTB = 'S' 
--        AND (
--            OPEIRRF = 'S'
--            OR (OPEISSQN = 'S' and GRUPO = 999 and (OPECINSS = 'S' OR OPECISSQN = 'S') )
--        )
--        --AND (PRIDATA BETWEEN (dataInicial::DATE - INTERVAL '1 MONTHS') AND dataFinal::DATE + INTERVAL '1 MONTHS')
--    group by t.ITECONTROL, opeirrf
--),
base AS (
    SELECT doc.CONTROLE,
        apl.aplseque as sequencia,
        doc.NOTDOCTO,
        doc.NOTSERIE,
        doc.NOTDATA,
        doc.NOTENTRADA,
        doc.OPERACAO,
        nfn.NNCNUMERO,
        nfn.NNCcontrol,
        emp1.EMPNOME AS EMPRESA_NOME,
        emp2.EMPNOME AS TRANSPORTADORA_NOME,
        doc.NOTESPECIE,
        doc2.NOTDOCTO AS CONHECIMENTO,
        doc2.NOTSERIE AS SERIE_CONHEC,
        apl.APLDESCRI,
        prod.pronome
    FROM DOCTOS doc
        LEFT JOIN NFNUMCOM nfn ON nfn.nnccontrol = doc.controle
        LEFT JOIN EMPRESA emp1 ON emp1.empresa = doc.notclifor
        LEFT JOIN EMPRESA emp2 ON emp2.empresa = doc.nostransp
        LEFT JOIN NOTFRETE ntf ON ntf.controle = doc.controle
        LEFT JOIN DOCTOS doc2 ON doc2.CONTROLE = ntf.CONTRFRE
        LEFT JOIN APLICA apl ON apl.aplcontrol = doc.CONTROLE
        LEFT JOIN TOQMOVI toq ON toq.itecontrol = apl.aplcontrol
        AND toq.prisequen = apl.aplseque
        LEFT JOIN PRODUTO prod ON prod.produto = toq.priproduto
),
le_base AS (
    select controle,
        sequencia,
        notdocto,
        coalesce(
            (
                CASE
                    WHEN length(trim(APLDESCRI)) > 0 THEN substring(APLDESCRI, 1, 50)
                    ELSE substring(pronome, 1, 50)
                END
            ),
            ''
        ) AS PINTCOM1,
        coalesce(CONHECIMENTO, '') AS PINTCOM2,
        coalesce(SERIE_CONHEC, '') AS PINTCOM3,
        coalesce(
            (
                CASE
                    WHEN NOTENTRADA IS NULL THEN ' de ' || trim(NOTDATA::text)
                    ELSE ' de ' || trim(NOTENTRADA::text)
                END
            ),
            ''
        ) AS PINTCOM4,
        coalesce(
            (
                CASE
                    WHEN OPERACAO < '4'
                    AND NNCcontrol > 0 THEN NNCNUMERO
                    ELSE NOTDOCTO
                END
            ),
            ''
        ) AS PINTCOM5,
        coalesce(EMPRESA_NOME, '') AS PINTCOM6,
        coalesce(NOTSERIE, '') AS PINTCOM7,
        coalesce(TRANSPORTADORA_NOME, '') AS PINTCOM8,
        coalesce(NOTESPECIE, '') AS PINTCOM9
    FROM base
    order by controle
),
--#PERIGO: CTE dados_tratados pode estar comentada enquanto trabalho nela, depois que for trabalhar depois no calculo ela volta a ser uma cte (assim posso usar o limit do dbeaver ao inves de colocar ele no SQL)
dados_tratados AS (
    select  
        'VEN'::TEXT as CTBIORIGEM,
        dataInicial::Date as CTBIDIAINI,
        pdeposito as CTBIDEPOSI,
        usuario as CTBIUSUAR,
        COALESCE(vlrtotirrf, 0) AS vlrtotirrf,
        t.ITECONTROL,
        PRISEQUEN,
        PRITRANSAC,
        t.OPERACAO operacaoTOQMOVI,
        coalesce(PRIVLDECON, 0) as PRIVLDECON,
        coalesce(PRIVLTOTAL, 0) as PRIVLTOTAL,
        PRIDEPOSIT,
        PRIDOCTO,
        PRIPRODUTO,
        PRIDATA,
        coalesce(PRICUSTO, 0) as PRICUSTO,
        coalesce(PRIDESCOF, 0) as PRIDESCOF,
        coalesce(PRIDESPIS, 0) as PRIDESPIS,
        coalesce(PRIVLDESP, 0) as PRIVLDESP,
        coalesce(PRIVLFRETE, 0) as PRIVLFRETE,
        coalesce(PRIICMFRET, 0) as PRIICMFRET,
        coalesce(PRIVLICMS, 0) as PRIVLICMS,
        coalesce(PRIVLRDIFI, 0) as PRIVLRDIFI,
        coalesce(PRIVLOUREC, 0) as PRIVLOUREC,
        coalesce(PRIVLSEGUR, 0) as PRIVLSEGUR,
        coalesce(PRIVLSUBST, 0) as PRIVLSUBST,
        coalesce(PRIVLPIS, 0) as PRIVLPIS,
        coalesce(PRIVLCOF, 0) as PRIVLCOF,
        coalesce(PRIVLCSLL, 0) as PRIVLCSLL,
        PRIBASEIPI,
        coalesce(PRIVLIPI, 0) as PRIVLIPI,
        PRIFVLRIPI,
        PRIQUANTI,
        GRUPO,
        SUBGRUPO,
        itmt.*,
        --itdc.*, --#PERIGO COMENTADA POIS NENHUMA COLUNA ESTA EM USO, JOINS PARA DESCRICAO PODEM SER FEITOS MAIS TARDE, APOS FILTROS APLICADOS
        so_o_que_precisa_do_pesimples_simplificado.*,
        retorna_icms_origem.*,
        subnotrete1.*,
        vlr_pis_st_e_cofins_st_STPISCOF.*,
        coalesce(difal.TQUFDCONT, 0) as TQUFDCONT,
        coalesce(difal.TQUFDSEQ, 0) as TQUFDSEQ,
        coalesce(difal.TQVLUFDEST, 0) as TQVLUFDEST,
        coalesce(difal.TQVLUFREME, 0) as TQVLUFREME,
        coalesce(difal.TQVLFCP, 0) as TQVLFCP,
        --# TODO: testar este "calculo" e join na cte "abaixo", onde o calculo e realizado? (nao realizei o teste pois ja estamos com performance ok)
        case
            when coalesce(valor_inss_n_INTCTB_PINTVLRINSS.vlrtotinss, 0) > 0
            and NOTVLINSS > 0
            and NOTVLBSINS > 0 then (
                (
                    PRIVLTOTAL / valor_inss_n_INTCTB_PINTVLRINSS.vlrtotinss
                ) * NOTVLINSS
            )
            else 0.00
        end as vlrinss,
        case
            when coalesce(valor_inss_n_INTCTB_PINTVLRINSS.vlrtotissqn, 0) > 0
            and NOTVLISSQN > 0
            AND NOTVLBSISS > 0 then (
                (
                    PRIVLTOTAL / valor_inss_n_INTCTB_PINTVLRINSS.vlrtotissqn
                ) * NOTVLISSQN
            )
        end as vlrissqn,
        case
            when coalesce(valor_inss_n_INTCTB_PINTVLRINSS.vlrtotirrf, 0) > 0
            and NOTVIRRF > 0
            and NOTVLNIRRF > 0 then (
                (
                    PRIVLTOTAL / valor_inss_n_INTCTB_PINTVLRINSS.vlrtotirrf
                ) * NOTVIRRF
            )
            else 0.00
        end as vlrirrf,
        dct.NOTDATA,
        dct.NOTENTRADA,
        dct.OPERACAO as operacaoDoctos,
        dct.NOTDEPORI as depositoNota,
        dct.NOTDEPDES as depositoDestinoNota,
        unnest(ARRAY [INTMPLC, INTMPLD]) AS conta_planoc,
        unnest(ARRAY ['C', 'D']) AS tipo_credito_debito,
        unnest(ARRAY [plcC.PLCNOME, plcD.PLCNOME]) AS PLANOC_PLCNOME,
        unnest(ARRAY [plcC.PLCCLASS, plcD.PLCCLASS]) AS PLANOC_PLCCLASS,
        unnest(ARRAY [plcC.PLCCLIRPJ, plcD.PLCCLIRPJ]) AS PLANOC_PLCCLIRPJ,
        unnest(ARRAY [plcC.PLCDLIRPJ, plcD.PLCDLIRPJ]) AS PLANOC_PLCDLIRPJ,
        unnest(ARRAY [plcC.PLCTLIRPJ, plcD.PLCTLIRPJ]) AS PLANOC_PLCTLIRPJ,
        unnest(ARRAY [plcC.PLCHLIRPJ, plcD.PLCHLIRPJ]) AS PLANOC_PLCHLIRPJ,
        unnest(ARRAY [plcC.PLCCLCSLL, plcD.PLCCLCSLL]) AS PLANOC_PLCCLCSLL,
        unnest(ARRAY [plcC.PLCDLCSLL, plcD.PLCDLCSLL]) AS PLANOC_PLCDLCSLL,
        unnest(ARRAY [plcC.PLCTLCSLL, plcD.PLCTLCSLL]) AS PLANOC_PLCTLCSLL,
        unnest(ARRAY [plcC.PLCCCUSTO, plcD.PLCCCUSTO]) AS PLANOC_PLCCCUSTO,
        unnest(ARRAY [plcC.PLCDCUSTO, plcD.PLCDCUSTO]) AS PLANOC_PLCDCUSTO,
        itdc.INTDACUM,
        hctb.hisnome,
        fn_erro_tipo_2_exp_ctb_ven(t.OPERACAO, PRIDEPOSIT, p.grupo, p.subgrupo)
    from toqmovi t
        LEFT JOIN so_o_que_precisa_do_pesimples_simplificado ON true
        left join produto p on p.produto = t.priproduto
        LEFT JOIN intmatr itmt on (
            itmt.operacao = t.operacao
            and itmt.intdepos = t.prideposit
            and (
                (
                    itmt.intgrupo = p.grupo
                    and itmt.intsubgrup = p.subgrupo
                )
                OR (
                    itmt.intgrupo = p.grupo
                    and itmt.intsubgrup = 0
                )
                OR (itmt.intgrupo = 0)
            )
        )
        /* REMOVIDO JOIN COM PLANOC PARA USAR O UNNEST */
        left join intdesc itdc on (itmt.intdcod = itdc.intdcod)
        LEFT JOIN retorna_icms_origem ON retorna_icms_origem.dcocontrol = t.ITECONTROL
        and retorna_icms_origem.dcosequen = PRISEQUEN
        /*Retencao dos Itens da Nota PVLRET34*/
        LEFT JOIN notrete1 subnotrete1 ON subnotrete1.ntrcontrol = t.ITECONTROL
        and subnotrete1.ntrproseq = PRISEQUEN
        LEFT JOIN vlr_pis_st_e_cofins_st_STPISCOF on vlr_pis_st_e_cofins_st_STPISCOF.STPICONT = t.ITECONTROL
        and vlr_pis_st_e_cofins_st_STPISCOF.STPISEQ = PRISEQUEN
        LEFT JOIN TOQOPINT as difal on TQUFDCONT = t.ITECONTROL
        AND TQUFDSEQ = PRISEQUEN
        LEFT JOIN doctos dct on dct.CONTROLE = t.ITECONTROL
        /*TODO: (AMBIGUIDADE) REVISAR SE e DA t QUE A COLUNA PRECISA SER LIDA!*/
        /*TODO: (ALIAS) Ricardo: coloquei dct mas nao sei se e o alias adequado*/
        LEFT JOIN valor_inss_n_INTCTB_PINTVLRINSS on valor_inss_n_INTCTB_PINTVLRINSS.ITECONTROL = t.ITECONTROL
        left join PLANOC plcC on plcC.PLANOC = INTMPLC
        left join PLANOC plcD on plcD.PLANOC = INTMPLD
        left join hisctb hctb on hctb.historico = itmt.historico
    WHERE --(PRIDATA BETWEEN (dataInicial::DATE ) AND dataFinal::DATE ) AND -- #PERIGO: Filtrar por PRIDATA melhora a performance, mas causa inconsistências em dados inconsistentes ¬¬' 
        (
            (
                (
                    dct.NOTDATA BETWEEN dataInicial AND dataFinal
                )
                and dct.OPERACAO > '4'
                and dct.NOTDEPORI > 0
            )
            or (
                (
                    dct.NOTENTRADA between dataInicial and dataFinal
                )
                and dct.OPERACAO > '0'
                and dct.OPERACAO < '4'
                and dct.NOTDEPDES > 0
            )
        )
        AND substr(NOTOBSFISC, 1, 10) <> 'NF ANULADA'
        AND notdocto <> ''
        AND notdocto IS NOT null
) --SELECT * FROM dados_tratados
/*abaixo e apenas o calculo, antes disso e o levantamento de informacoes necessarias*/
SELECT --Simplificacao calculo de valores        
    --Variaveis &ntrprovpis, &ntrprovcof, &ntrprovcsl recuperadas pelo PVLRET34 ja estao disponiveis pelo join com a notrete1	
    0 + fn_valor_conforme_operador(true, INTMVCUST, PRICUSTO) + fn_valor_conforme_operador(
        true,
        INTMVDESC,
        PRIVLDECON + PRIDESCOF + PRIDESPIS
    ) + fn_valor_conforme_operador(true, INTMVFRET, PRIVLFRETE) + fn_valor_conforme_operador(true, INTMVIFRE, PRIICMFRET * multicms) + fn_valor_conforme_operador(
        true,
        INTMVICMS,
        (PRIVLICMS * multicms) + (
            fn_valor_conforme_operador(
                coalesce(quantidadeOrigem, 0) > 0,
                INTMVICMS,
                coalesce(
                    round(
                        (priquanti * tosvlcred) / quantidadeOrigem,
                        2
                    ),
                    0
                )
            )
        )
    ) + fn_valor_conforme_operador(true, INTMVDIFIC, PRIVLRDIFI) + fn_valor_conforme_operador(true, INTMVOURE, PRIVLOUREC) + fn_valor_conforme_operador(true, INTMVSEGU, PRIVLSEGUR) + fn_valor_conforme_operador(true, INTMVSUBS, PRIVLSUBST) + fn_valor_conforme_operador(true, INTMVLPIS, PRIVLPIS) + fn_valor_conforme_operador(true, INTMVLCOF, PRIVLCOF) + fn_valor_conforme_operador(true, INTMVLCSL, PRIVLCSLL) + fn_valor_conforme_operador(true, INTMVTOTA, PRIVLTOTAL) + fn_valor_conforme_operador(
        coalesce(PRIVLDESP, 0) > 0,
        INTMVDESP,
        PRIVLDESP - (
            coalesce(vlrpisst, 0) + coalesce(vlrcofst, 0)
        )
    ) + fn_valor_conforme_operador(
        coalesce(vlrpisst, 0) > 0,
        INTPISST,
        coalesce(vlrpisst, 0)
    ) + fn_valor_conforme_operador(vlrcofst > 0, INTCOFINSS, coalesce(vlrcofst, 0)) + fn_valor_conforme_operador(
        (
            PRIBASEIPI <> 50
            OR PRITRANSAC = 5
            /*TODO: (AMBIGUIDADE) REVISAR SE e DA dados_tratados QUE A COLUNA PRECISA SER LIDA!*/
            OR (
                /*&soipi [INICIO]*/
                case
                    when INTMVCUST in ('+', '-')
                    or INTMVDESC in ('+', '-')
                    or INTMVDESP in ('+', '-')
                    or INTMVFRET in ('+', '-')
                    or INTMVIFRE in ('+', '-')
                    or INTMVICMS in ('+', '-')
                    or INTMVDIFIC in ('+', '-')
                    or INTMVOURE in ('+', '-')
                    or INTMVSEGU in ('+', '-')
                    or INTMVSUBS in ('+', '-')
                    or INTMVLPIS in ('+', '-')
                    or INTMVLCOF in ('+', '-')
                    or INTMVLCSL in ('+', '-')
                    or INTMRTPIS in ('+', '-')
                    or INTMRTCOF in ('+', '-')
                    or INTMRTCSLL in ('+', '-')
                    or INTMVTOTA in ('+', '-')
                    or (
                        coalesce(vlrpisst, 0) > 0
                        and INTPISST in ('+', '-')
                    )
                    or (
                        coalesce(vlrcofst, 0) > 0
                        and INTCOFINSS in ('+', '-')
                    ) then 'N'
                end
                /*&soipi [FIM]*/
            ) <> 'N'
        ),
        INTMVIPI,
        (
            PRIVLIPI + fn_valor_conforme_operador(true, INTMVIPI, PRIFVLRIPI)
        )
    ) + fn_valor_conforme_operador(true, INTMRTPIS, NTRPROVPIS) + fn_valor_conforme_operador(true, INTMRTCOF, NTRPROVCOF) + fn_valor_conforme_operador(true, INTMRTCSLL, NTRPROVCSL) + fn_valor_conforme_operador(
        length(trim(INTMDEST)) > 0
        OR length(trim(INTMREMET)) > 0
        OR length(trim(INTMFCP)) > 0,
        INTMDEST,
        TQVLUFDEST
    ) + fn_valor_conforme_operador(
        length(trim(INTMDEST)) > 0
        OR length(trim(INTMREMET)) > 0
        OR length(trim(INTMFCP)) > 0,
        INTMREMET,
        TQVLUFREME
    ) + fn_valor_conforme_operador(
        length(trim(INTMDEST)) > 0
        OR length(trim(INTMREMET)) > 0
        OR length(trim(INTMFCP)) > 0,
        INTMFCP,
        TQVLFCP
    ) + fn_valor_conforme_operador(
        vlrinss + vlrissqn + vlrirrf <> 0,
        INTMVIRF,
        vlrirrf
    ) + fn_valor_conforme_operador(
        vlrinss + vlrissqn + vlrirrf <> 0,
        INTMVINSS,
        vlrinss
    ) + fn_valor_conforme_operador(
        vlrinss + vlrissqn + vlrirrf <> 0,
        INTMISSQN,
        vlrissqn
    ) AS CALCULO,
    dados_tratados.*,
    lb.*
FROM dados_tratados
    left join le_base lb on itecontrol = lb.controle
    and (
        lb.sequencia is null
        or prisequen = lb.sequencia
    );
END;
$BODY$ LANGUAGE plpgsql VOLATILE COST 100;
ALTER FUNCTION fn_apura_exportacao_contabilidade_vendas(int, date, date, text) OWNER TO postgres;