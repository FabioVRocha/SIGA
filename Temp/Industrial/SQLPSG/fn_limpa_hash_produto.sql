-- Function: fn_limpa_hash_produto(character)

-- DROP FUNCTION fn_limpa_hash_produto(character);

CREATE OR REPLACE FUNCTION fn_limpa_hash_produto(pproduto character)
  RETURNS boolean AS
$BODY$
DECLARE

BEGIN
	--SOBE A ESTRUTURA PARA TODOS OS PAIS LIMPANDO
	update estrutur e set esthash ='' from 
	(
		select t.estproduto,t.estfilho --,e.esthash as hash_produto
		from  connectby('estrutur', 'estproduto', 'estfilho', pproduto, 999, '<-') AS t(estproduto character(16), estfilho character(16), nivel int, caminho text)
		--left join estrutur e on ((e.estproduto,e.estfilho) = (t.estproduto,t.estfilho))
		where nivel > 0
			
		union

		select estproduto,estfilho  from estrutur where estproduto = pproduto  and esthash <> ''
	) cte
	where e.estproduto = cte.estproduto and not nullif(esthash, '') is null;

	return FOUND;

END;$BODY$
  LANGUAGE plpgsql VOLATILE --SECURITY DEFINER
  COST 100;
ALTER FUNCTION fn_limpa_hash_produto(character)
  OWNER TO postgres;
