-- Function: fn_cfop_ncm_notas_periodo(text, text, text)
-- DROP FUNCTION fn_cfop_ncm_notas_periodo(text, text, text);
CREATE OR REPLACE FUNCTION fn_cfop_ncm_notas_periodo(usuario text, dataInicial text, dataFinal text) RETURNS void AS $BODY$ BEGIN
insert into UMCOTA(UMCOTEST, UMCOTFOR, UMCOTPROD, UMCOTACAO, UMCOTPRONO, UMCOTORDEM, UMCOFONC, UMCOTVAL) 
(select
	usuario,
	row_number() over(),
	'1',
	1,	
	opeopofi,
	opedescri,
	classifica,
	clanome
from
	(
	select
		distinct opeopofi,
		opedescri,
		classifica,
		clanome
	from
		(
		select
			distinct priclascod,
			operacao
		from
			toqmovi
		where
			itecontrol in (
			select
				controle
			from
				doctos
			where
				notdtdigit is not null
				and notmodelo in('55', '65')
					and notstatus = 'A'
					and notensai = 'S'
					and notdata between dataInicial::date and dataFinal::date                        
                    )
            ) as toq_filtrada
	left join (
		select
			classifica,
			clascod,
			clanome
		from
			classi
            ) as col_classi on
		col_classi.clascod = toq_filtrada.priclascod
	join (
		select
			opeopofi,
			operacao,
			opedescri
		from
			opera
		where
			opeobf = 'S'
            ) as col_operacao on
		col_operacao.operacao = toq_filtrada.operacao
	order by
		opeopofi,
		classifica
    ) as sub);

    return;
END;
$BODY$ LANGUAGE plpgsql VOLATILE COST 100;
ALTER FUNCTION fn_cfop_ncm_notas_periodo(text, text, text) OWNER TO postgres;