--drop function fn_grava_descricao_erro_tipo_1_exp_ctb_ven(text, date)
CREATE OR REPLACE FUNCTION fn_grava_descricao_erro_tipo_1_exp_ctb_ven(usuario text, dataInicial date) 
returns void
AS $$ 
DECLARE	
	ultSequen int;
BEGIN

select coalesce(MAX(UMPZSEQUEN), 0) into ultSequen from umpedzoo where umpzusuari = usuario;

insert into UMPEDZOO(UMPZUSUARI, UMPZSEQUEN, UMPZTEXTO)
select 
	usuario as usuario,
	(ultSequen + row_number() over()) as seq,
	fn_descricao_erro_tipo_1_exp_ctb_ven 
from
(select 
	pridocto,
	case
		when ((intmcod = 0 or intmcod is null) and calculo > 0) then true
		else false
	end as erro_tipo_1,
	fn_descricao_erro_tipo_1_exp_ctb_ven(grupo, subgrupo, INTLDES, pridocto, pridata, priproduto, operacao, prideposit, itecontrol, prisequen)
from temp_apuracao_vendas
join intlanc on intlope = operacao and intldep = prideposit and intlgru = grupo and intlsub = subgrupo
where ctbidiaini = dataInicial) as sub
where erro_tipo_1
order by pridocto;
END;
$$ LANGUAGE plpgsql;
ALTER FUNCTION fn_grava_descricao_erro_tipo_1_exp_ctb_ven(text, date) OWNER TO postgres;
