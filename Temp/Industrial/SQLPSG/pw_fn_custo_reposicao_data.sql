-- Function: pw_fn_custo_reposicao_data(character, numeric, date)

-- DROP FUNCTION pw_fn_custo_reposicao_data(character, numeric, date);

CREATE OR REPLACE FUNCTION pw_fn_custo_reposicao_data(p_produto character, p_deposito numeric, p_data date)
  RETURNS numeric AS
$BODY$
declare
	custorep numeric(15,4);
	multiempresa character(1);
begin
	
	/*[12/08/2022, 3475620, Ricardo K] Prever Custo de Reposicao na data de emissao da nota. (FERRANTE)
	A funcao vai retornar o custo de reposicao conforme a data recebida por parametro, buscando esta 
	informacao no historico e filtrando por deposito quando a base for multiempresa.
	Caso nao seja possivel buscar o custo do historico, sera buscado do produto. */
	SELECT into multiempresa dadmulemp FROM public.dadosemp where dadempresa = 1;
	
	select into custorep
	hicuvlrcu
	from public.hiscusto
	where hicuproco = p_produto 
		and hicudatal <= p_data 
		and (multiempresa = 'S' OR hicudepo = p_deposito)
		
	order by hicudatal DESC, hicuhoral DESC
	limit 1;
	
	if (custorep is null) then 
		select into custorep
		procusrep
		from public.produto
		where produto = p_produto;

	end if;
	
	return custorep;
	
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_custo_reposicao_data(character, numeric, date) SET search_path=public, pg_temp;

ALTER FUNCTION pw_fn_custo_reposicao_data(character, numeric, date)
  OWNER TO postgres;
