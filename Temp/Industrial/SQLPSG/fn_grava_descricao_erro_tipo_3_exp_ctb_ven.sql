--drop function fn_grava_descricao_erro_tipo_3_exp_ctb_ven(text, date)
CREATE OR REPLACE FUNCTION fn_grava_descricao_erro_tipo_3_exp_ctb_ven(usuario text, dataInicial date) 
returns void
AS $$ 
DECLARE	
	ultSequen int;
BEGIN

select coalesce(MAX(UMPZSEQUEN), 0) into ultSequen from umpedzoo where umpzusuari = usuario;

insert into UMPEDZOO(UMPZUSUARI, UMPZSEQUEN, UMPZTEXTO)
select usuario as usuario,
    (ultSequen + row_number() over()) as seq,
    fn_descricao_erro_tipo_3_exp_ctb_ven(
        CTBICCUSTO,
        CTBIPLANOC,
        CTBINHIST,
        CTBIHISTOR_completo,
        calculo,
        pritransac,
        CTBIDBCR,
        CTBIDIAINI,
        pridocto,
        intmcod,
        operacao,
        CTBICONTR,
        prisequen
    )
from (
        select CTBIDIAINI,
            case
                when tipo_credito_debito = 'D' then INTMCUD
                when tipo_credito_debito = 'C' then INTMCUC
            end as CTBICCUSTO,
            case
                when tipo_credito_debito = 'D' then INTMPLD
                when tipo_credito_debito = 'C' then INTMPLC
            end as CTBIPLANOC,
            tipo_credito_debito as CTBIDBCR,
            calculo,
            HISTORICO as CTBINHIST,
            trim(HISNOME) || '-' || fn_get_elementos_ordenados(
                array [intmcapli, intmcconh, intmccose, intmcdata, intmcdocu, intmcempr, intmcseri,  intmctran, intmcespec],
                array [PINTCOM1,PINTCOM2,PINTCOM3,PINTCOM4,PINTCOM5,PINTCOM6,PINTCOM7,PINTCOM8,PINTCOM9]
            ) as CTBIHISTOR_completo,
            itecontrol as CTBICONTR,
            pritransac,
            intmcod,
            pridocto,
            operacao,
            prisequen
        from temp_apuracao_vendas
        where ctbidiaini = dataInicial
        order by pridocto
    ) as sub
where fn_erro_tipo_3_exp_ctb_ven(
        CTBICCUSTO,
        CTBIPLANOC,
        CTBINHIST,
        CTBIHISTOR_completo,
        calculo,
        pritransac
    );

insert into UMCHEQUE(UMCHUSUARI, UMCHSEQUEN)
select 
	'ERROTIPO3' as usuerro3,
	intmcod
from (
        select CTBIDIAINI,
            case
                when tipo_credito_debito = 'D' then INTMCUD
                when tipo_credito_debito = 'C' then INTMCUC
            end as CTBICCUSTO,
            case
                when tipo_credito_debito = 'D' then INTMPLD
                when tipo_credito_debito = 'C' then INTMPLC
            end as CTBIPLANOC,            
            calculo,
            HISTORICO as CTBINHIST,
            trim(HISNOME) || '-' || fn_get_elementos_ordenados(
                array [intmcapli, intmcconh, intmccose, intmcdata, intmcdocu, intmcempr, intmcseri,  intmctran, intmcespec],
                array [PINTCOM1,PINTCOM2,PINTCOM3,PINTCOM4,PINTCOM5,PINTCOM6,PINTCOM7,PINTCOM8,PINTCOM9]
            ) as CTBIHISTOR_completo,            
            pritransac,
            intmcod,
            pridocto                       
        from temp_apuracao_vendas
        where ctbidiaini = dataInicial
        order by pridocto
    ) as sub
where fn_erro_tipo_3_exp_ctb_ven(
        CTBICCUSTO,
        CTBIPLANOC,
        CTBINHIST,
        CTBIHISTOR_completo,
        calculo,
        pritransac
    ) and intmcod is not null
group by usuerro3, intmcod     
order by intmcod;
END;
$$ LANGUAGE plpgsql;
ALTER FUNCTION fn_grava_descricao_erro_tipo_3_exp_ctb_ven(text, date) OWNER TO postgres;