--drop function fn_qtd_erros_tipo_3_exp_ctb_ven(date)
CREATE OR REPLACE FUNCTION fn_qtd_erros_tipo_3_exp_ctb_ven(dataInicial date) RETURNS INTEGER AS $$ 
DECLARE
    qtdErros integer;
BEGIN --Retorna qtd erros tipo 3 da exportacao de VENDAS para a contabilidade
select count(*) into qtdErros
from (
		select case
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
			ctbidiaini
		from temp_apuracao_vendas
	) as sub
where fn_erro_tipo_3_exp_ctb_ven(
		CTBICCUSTO,
		CTBIPLANOC,
		CTBINHIST,
		CTBIHISTOR_completo,
		calculo,
		pritransac
	) and ctbidiaini = dataInicial;

    return qtdErros;
END;
$$ LANGUAGE plpgsql VOLATILE COST 100;
ALTER FUNCTION fn_qtd_erros_tipo_3_exp_ctb_ven(date) OWNER TO postgres;