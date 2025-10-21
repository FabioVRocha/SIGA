-- Function: fn_gerar_hash_produto_estrutura(character, character, character, character)

-- DROP FUNCTION fn_gerar_hash_produto_estrutura(character, character, character, character);

CREATE OR REPLACE FUNCTION fn_gerar_hash_produto_estrutura(pproduto character, pengestver character, pgenerico character, pconfatmed character)
  RETURNS text AS
$BODY$
DECLARE
	r_estrutura record;
	vtexto text;
	vhash_anterior text;
	vhash_atual text;
	--vcontador integer;
	vtotal integer;
	vexiste boolean;
BEGIN
	/*[18/05/2022, 3725822, Ricardo K] Melhoria de performance no HASH de estrutura.
	
	Funcao busca o hash atual, gera o hash da estrutura sem salvar e compara.
	Caso o hash esteja diferente, sera limpo no produto e em todos os pais dele.
	Sera gerado o novo hash dessa estrutura e gravado.
	Sera gerado o hash de cada pai e gravado.
	
	*/
	select true , trim(esthash) 
	from estrutur 
	where estproduto = pproduto 
		--and nullif(trim(esthash), '') is not null --ao inves de filtrar pelo hash pode ordenar para que os null venham no final
	order by nullif(trim(esthash), '') desc
	limit 1 
	into vexiste, vhash_anterior;

	if vexiste is null then
		RAISE NOTICE 'Produto % INEXISTENTE na ESTRUTURA.', pproduto 
		USING HINT = 'Produto nao existe na estrutura mas tentou calcular HASH: ' || pproduto;

		return 'Produto ' || pproduto || ' INEXISTENTE na ESTRUTURA.';
	end if;


	--Raise NOTICE 'Chamou fn_gerar_hash_produto_estrutura(% ...', coalesce(pproduto, 'NULL');

	--Se o hash existente na tabela estiver em branco, sera necessario calcular de qq forma, entao deixa para calcular salvando ja.
	if nullif(vhash_anterior, '') is not null then
		select fn_gerar_hash(pproduto,pengestver,'N'/*Grava Hash*/,'N'/*nao faz diferenca*/,pgenerico,pconfatmed,'USUARIO'/*nao faz diferenca*/,'S'/*nao faz diferenca*/) into vhash_atual;
	end if;
	
	if vhash_atual = vhash_anterior and (nullif(vhash_anterior, '') is not null) then

/*
		--A funcao que gera hash que deve se encarregar de atualizar o horario de geracao do hash
		update estrutur set estdthash = current_date,
			esthrhash = substring(current_time::text, 1, 8),
			esthash = vhash_atual
		where estproduto = pproduto 
			and (
				esthash <> vhash_atual
				OR estdthash <> current_date
				OR esthrhash <> substring(current_time::text, 1, 8)
			); 
*/
		return 'Hash nao mudou: ' || vhash_atual;
	else
		perform fn_limpa_hash_produto(pproduto);
	end if;

	--GERA O HASH DO PRODUTO PASSADO POR PARAMETRO
	select fn_gerar_hash(pproduto,pengestver,'S'/*Grava Hash*/,'N'/*nao faz diferenca*/,pgenerico,pconfatmed,'USUARIO'/*nao faz diferenca*/,'S'/*nao faz diferenca*/)into vhash_atual;

	--se tem um hash valido, mas diferente do atual, vai gerar novamente dos pais das estruturas onde ele e usado
	if length(vhash_atual) = 32 then 

		/*
		vtotal = (
			select count(*) from (
				select distinct on (estproduto) *
				from  connectby('estrutur', 'estproduto', 'estfilho', pproduto, 999, '->') AS t(estproduto character(16), estfilho character(16), nivel int, caminho text)
				where nivel > 0
				order by estproduto
			) est
		);

		vcontador = 0;
		*/
		for r_estrutura in (
			--select * from (
				select distinct on (estproduto) estproduto --*
				from  connectby('estrutur', 'estproduto', 'estfilho', pproduto, 999, '->') AS t(estproduto character(16), estfilho character(16), nivel int, caminho text)
				where nivel > 0
				order by estproduto
				--limit 3
			--) t
			--order by nivel desc
		) loop
			--vcontador = vcontador + 1;
			--RAISE NOTICE 'gerando % ', coalesce(vcontador, 0) || ' de ' || coalesce(vtotal, 0)
			--USING HINT = 'gerando ' || coalesce(r_estrutura.estproduto, 'estproduto null') || ' Pai de ' || coalesce(r_estrutura.estfilho, 'estfilho null');

			vtexto= r_estrutura.estproduto || ' ' || coalesce(fn_gerar_hash(r_estrutura.estproduto,pengestver,'S'/*Gravar Hash*/,'S'/*nao faz diferenca*/,pgenerico,pconfatmed,'USUARIO'/*nao faz diferenca*/,'S'/*nao faz diferenca*/), 'nao gerou');

		end loop;
/*
		--Teste para verificar se executa mais rapido do que no loop
		perform select distinct on (nivel,estproduto) fn_gerar_hash(estproduto,'S','S','S','N','N',pusuario,'S')
		from  connectby('estrutur', 'estproduto', 'estfilho', pproduto, 999, '->') AS t(estproduto character(16), estfilho character(16), nivel int, caminho text)
		where nivel > 0
		order by nivel, estproduto;
*/
	else
		Raise Exception 'Hash atual do produto nao possui o tamanho correto. Devia ser character(32) mas e (%)! Nao vai gerar os hashes das estruturas onde ele e usado.', coalesce(vhash_atual, 'NULL');
	end if;

	return 'Hash anterior -> novo: ' || coalesce(vhash_anterior, 'null') ||  ' -> ' || vhash_atual || '. Hash do ultimo produto gerado: ' || vtexto;

END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_gerar_hash_produto_estrutura(character, character, character, character)
  OWNER TO postgre