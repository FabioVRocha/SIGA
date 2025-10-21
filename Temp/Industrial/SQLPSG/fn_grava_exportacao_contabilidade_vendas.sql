--drop function fn_grava_exportacao_contabilidade_vendas(date)
create or replace function fn_grava_exportacao_contabilidade_vendas(dataInicial date) RETURNS void as $BODY$
BEGIN
insert into ctbimp1(CTBIORIGEM, CTBIDIAINI, CTBIDEPOSI, CTBISEQUEN, CTBIDATA, CTBICCUSTO, CTBIPLANOC, CTBIDBCR, CTBIVALOR, CTBIVACUM, CTBICLASS, CTBINHIST, CTBIHISTOR, CTBIACUMUL, CTBICONTR, CTBITITULO, CTBIUSUAR, CTBICLIRPJ, CTBIDLIRPJ, CTBITLIRPJ, CTBIHLIRPJ, CTBICLCSLL, CTBIDLCSLL, CTBITLCSLL, CTBICODCUS, CTBIDESCUS)
select
	CTBIORIGEM,
	CTBIDIAINI,
	CTBIDEPOSI,	
    row_number() over() as CTBISEQUEN,
	CTBIDATA,
	CTBICCUSTO,		
	CTBIPLANOC,	
	CTBIDBCR,
	CTBIVALOR,
	CTBIVACUM,
	CTBICLASS,
	CTBINHIST,
    CTBIHISTOR,    
	CTBIACUMUL,
	CTBICONTR,
	CTBITITULO,
	CTBIUSUAR,
	CTBICLIRPJ,
	CTBIDLIRPJ,
	CTBITLIRPJ,
	CTBIHLIRPJ,
	CTBICLCSLL,
	CTBIDLCSLL,
	CTBITLCSLL,
	CTBICODCUS,
	CTBIDESCUS	
from
(select 
	CTBIORIGEM,
	CTBIDIAINI,
	CTBIDEPOSI,	    
	CTBIDATA,
	CTBICCUSTO,		
	CTBIPLANOC,	
	CTBIDBCR,
	sum(CTBIVALOR) as CTBIVALOR,
	sum(CTBIVACUM) as CTBIVACUM,
	CTBICLASS,
	CTBINHIST,
    coalesce(substring(CTBIHISTOR_completo, 1, 72), '') as CTBIHISTOR,    
	CTBIACUMUL,
	CTBICONTR,
	CTBITITULO,
	CTBIUSUAR,
	CTBICLIRPJ,
	CTBIDLIRPJ,
	CTBITLIRPJ,
	CTBIHLIRPJ,
	CTBICLCSLL,
	CTBIDLCSLL,
	CTBITLCSLL,
	CTBICODCUS,
	CTBIDESCUS   
from
(select
	CTBIORIGEM,
	CTBIDIAINI,
	CTBIDEPOSI,	 
	pridata as CTBIDATA,
	case
		when tipo_credito_debito = 'D' then INTMCUD
		when tipo_credito_debito = 'C' then INTMCUC
	end as CTBICCUSTO,		
	case
		when tipo_credito_debito = 'D' then INTMPLD 
		when tipo_credito_debito = 'C' then INTMPLC
	end	as CTBIPLANOC,	
	tipo_credito_debito as CTBIDBCR,
	sum(calculo) as CTBIVALOR,
	sum(calculo) as CTBIVACUM,
	INTMCLASS as CTBICLASS,
	HISTORICO as CTBINHIST,
    trim(HISNOME) || '-' || fn_get_elementos_ordenados(array[intmcapli, intmcconh, intmccose, intmcdata, intmcdocu, intmcempr, intmcseri,  intmctran, intmcespec], array[PINTCOM1,PINTCOM2,PINTCOM3,PINTCOM4,PINTCOM5,PINTCOM6,PINTCOM7,PINTCOM8,PINTCOM9])  as CTBIHISTOR_completo,    
	case
		when INTDACUM = 'D' then '3'
		when INTDACUM = 'P' then '4'
		else ' '
	end as CTBIACUMUL,
	itecontrol as CTBICONTR,
	''::TEXT as CTBITITULO,
	CTBIUSUAR,
	PLANOC_PLCCLIRPJ as CTBICLIRPJ,
	PLANOC_PLCDLIRPJ as CTBIDLIRPJ,
	PLANOC_PLCTLIRPJ as CTBITLIRPJ,
	PLANOC_PLCHLIRPJ as CTBIHLIRPJ,
	PLANOC_PLCCLCSLL as CTBICLCSLL,
	PLANOC_PLCDLCSLL as CTBIDLCSLL,
	PLANOC_PLCTLCSLL as CTBITLCSLL,
	PLANOC_PLCCCUSTO as CTBICODCUS,
	PLANOC_PLCDCUSTO as CTBIDESCUS,
	pridocto    
from
	temp_apuracao_vendas    
	--Como a contabilidade oficial não possui lançamentos 0, devemos desconsidera-los para ficar com a mesma quantidade de registros.    
where
	calculo <> 0
group by
	notdata,
	pridata,
	itecontrol,
	conta_planoc,
	tipo_credito_debito,
	historico,
	PLANOC_PLCNOME,
	PLANOC_PLCCLASS,
	PLANOC_PLCCLIRPJ,
	PLANOC_PLCDLIRPJ,
	PLANOC_PLCTLIRPJ,
	PLANOC_PLCHLIRPJ,
	PLANOC_PLCCLCSLL,
	PLANOC_PLCDLCSLL,
	PLANOC_PLCTLCSLL,
	PLANOC_PLCCCUSTO,
	PLANOC_PLCDCUSTO,
	INTMCUD,
	INTMPLD,
	tipo_credito_debito,
	INTMCLASS,
	INTDACUM,	
	PINTCOM1,
	PINTCOM2,
	PINTCOM3,
	PINTCOM4,
	PINTCOM5,
	PINTCOM6,
	PINTCOM7,
	PINTCOM8,
	PINTCOM9,
	HISNOME,
    intmcapli, 
    intmcconh, 
    intmccose, 
    intmcdata, 
    intmcdocu, 
    intmcempr, 
    intmcseri, 
    intmctran, 
    intmcespec,
    INTMCUC,
    INTMPLC,
    CTBIORIGEM,
    CTBIDIAINI,
    CTBIDEPOSI,
    CTBIUSUAR,
	pridocto) as sub
    group by
	CTBIORIGEM,
	CTBIDIAINI,
	CTBIDEPOSI,	
	CTBIDATA,
	CTBICCUSTO,		
	CTBIPLANOC,	
	CTBIDBCR,
	CTBICLASS,
	CTBINHIST,
    CTBIHISTOR_completo,    
	CTBIACUMUL,
	CTBICONTR,
	CTBITITULO,
	CTBIUSUAR,
	CTBICLIRPJ,
	CTBIDLIRPJ,
	CTBITLIRPJ,
	CTBIHLIRPJ,
	CTBICLCSLL,
	CTBIDLCSLL,
	CTBITLCSLL,
	CTBICODCUS,
	CTBIDESCUS,
	pridocto
	order by pridocto, CTBINHIST, CTBIDBCR desc) as sub2;

    update ctbimp set ctbimaxseq = (select max(ctbisequen) from ctbimp1 where ctbiorigem = 'VEN' and ctbidiaini = dataInicial) where ctbiorigem = 'VEN' and ctbidiaini = dataInicial;

	insert into ctbimp2(CTBIORIGEM, CTBIDIAINI, CTBISEQUEN, CTBIDEPOSI, CTBIHSEQ, CTBIHHIST)
	select
		CTBIORIGEM, CTBIDIAINI, row_number() over() as CTBISEQUEN, CTBIDEPOSI, CTBIHSEQ, coalesce(substring(CTBIHHIST, 73, 72), '')
	from
	(select 
		CTBIORIGEM, 
		CTBIDIAINI, 		
		CTBIDEPOSI,
		1 as CTBIHSEQ,	
		CTBIHISTOR_completo as CTBIHHIST			    		
	from
	(select
		CTBIORIGEM,
		CTBIDIAINI,
		CTBIDEPOSI,	 
		pridata as CTBIDATA,
		case
			when tipo_credito_debito = 'D' then INTMCUD
			when tipo_credito_debito = 'C' then INTMCUC
		end as CTBICCUSTO,		
		case
			when tipo_credito_debito = 'D' then INTMPLD 
			when tipo_credito_debito = 'C' then INTMPLC
		end	as CTBIPLANOC,	
		tipo_credito_debito as CTBIDBCR,
		sum(calculo) as CTBIVALOR,
		sum(calculo) as CTBIVACUM,
		INTMCLASS as CTBICLASS,
		HISTORICO as CTBINHIST,
		trim(HISNOME) || '-' || fn_get_elementos_ordenados(array[intmcapli, intmcconh, intmccose, intmcdata, intmcdocu, intmcempr, intmcseri,  intmctran, intmcespec], array[PINTCOM1,PINTCOM2,PINTCOM3,PINTCOM4,PINTCOM5,PINTCOM6,PINTCOM7,PINTCOM8,PINTCOM9])  as CTBIHISTOR_completo,    
		case
			when INTDACUM = 'D' then '3'
			when INTDACUM = 'P' then '4'
			else ' '
		end as CTBIACUMUL,
		itecontrol as CTBICONTR,
		''::TEXT as CTBITITULO,
		CTBIUSUAR,
		PLANOC_PLCCLIRPJ as CTBICLIRPJ,
		PLANOC_PLCDLIRPJ as CTBIDLIRPJ,
		PLANOC_PLCTLIRPJ as CTBITLIRPJ,
		PLANOC_PLCHLIRPJ as CTBIHLIRPJ,
		PLANOC_PLCCLCSLL as CTBICLCSLL,
		PLANOC_PLCDLCSLL as CTBIDLCSLL,
		PLANOC_PLCTLCSLL as CTBITLCSLL,
		PLANOC_PLCCCUSTO as CTBICODCUS,
		PLANOC_PLCDCUSTO as CTBIDESCUS,
		pridocto  
	from
		temp_apuracao_vendas    
		--Como a contabilidade oficial não possui lançamentos 0, devemos desconsiderá-los para ficar com a mesma quantidade de registros.    
	where
		calculo <> 0
	group by
		notdata,
		pridata,
		itecontrol,
		conta_planoc,
		tipo_credito_debito,
		historico,
		PLANOC_PLCNOME,
		PLANOC_PLCCLASS,
		PLANOC_PLCCLIRPJ,
		PLANOC_PLCDLIRPJ,
		PLANOC_PLCTLIRPJ,
		PLANOC_PLCHLIRPJ,
		PLANOC_PLCCLCSLL,
		PLANOC_PLCDLCSLL,
		PLANOC_PLCTLCSLL,
		PLANOC_PLCCCUSTO,
		PLANOC_PLCDCUSTO,
		INTMCUD,
		INTMPLD,
		tipo_credito_debito,
		INTMCLASS,
		INTDACUM,	
		PINTCOM1,
		PINTCOM2,
		PINTCOM3,
		PINTCOM4,
		PINTCOM5,
		PINTCOM6,
		PINTCOM7,
		PINTCOM8,
		PINTCOM9,
		HISNOME,
		intmcapli, 
		intmcconh, 
		intmccose, 
		intmcdata, 
		intmcdocu, 
		intmcempr, 
		intmcseri, 
		intmctran, 
		intmcespec,
		INTMCUC,
		INTMPLC,
		CTBIORIGEM,
		CTBIDIAINI,
		CTBIDEPOSI,
		CTBIUSUAR,
		pridocto) as sub    
		group by
		CTBIORIGEM,
		CTBIDIAINI,
		CTBIDEPOSI,	
		CTBIDATA,
		CTBICCUSTO,		
		CTBIPLANOC,	
		CTBIDBCR,
		CTBICLASS,
		CTBINHIST,
		CTBIHISTOR_completo,    
		CTBIACUMUL,
		CTBICONTR,
		CTBITITULO,
		CTBIUSUAR,
		CTBICLIRPJ,
		CTBIDLIRPJ,
		CTBITLIRPJ,
		CTBIHLIRPJ,
		CTBICLCSLL,
		CTBIDLCSLL,
		CTBITLCSLL,
		CTBICODCUS,
		CTBIDESCUS,
		pridocto
		order by pridocto, CTBINHIST, CTBIDBCR desc) as sub2
		where length(trim(coalesce(substring(CTBIHHIST, 73, 72), ''))) > 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_grava_exportacao_contabilidade_vendas(date)
  OWNER TO postgres;