--drop function fn_grava_descricao_erro_tipo_2_exp_ctb_ven(text, date)
CREATE OR REPLACE FUNCTION fn_grava_descricao_erro_tipo_2_exp_ctb_ven(usuario text, dataInicial date) 
returns void
AS $$ 
DECLARE	
	ultSequen int;
BEGIN

select coalesce(MAX(UMPZSEQUEN), 0) into ultSequen from umpedzoo where umpzusuari = usuario;

insert into UMPEDZOO(UMPZUSUARI, UMPZSEQUEN, UMPZTEXTO)
select usuario as usuario,
    (ultSequen + row_number() over()) as seq,
    fn_descricao_erro_tipo_2_exp_ctb_ven(pridocto, pridata, priproduto, operacao, prideposit, CTBICONTR, prisequen)
from (
        select 
			fn_erro_tipo_2_exp_ctb_ven,
            itecontrol as CTBICONTR,
            pridocto,
            operacao,
            prisequen,
            pridata,
            priproduto,
            prideposit
        from temp_apuracao_vendas
        where ctbidiaini = dataInicial and fn_erro_tipo_2_exp_ctb_ven
        group by fn_erro_tipo_2_exp_ctb_ven, itecontrol, pridocto, operacao, prisequen, pridata, priproduto, prideposit
        order by pridocto     
    ) as sub;
END;
$$ LANGUAGE plpgsql;
ALTER FUNCTION fn_grava_descricao_erro_tipo_2_exp_ctb_ven(text, date) OWNER TO postgres;