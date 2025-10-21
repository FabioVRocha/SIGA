-- Function: fn_gerar_hash_geral()

-- DROP FUNCTION fn_gerar_hash_geral();

CREATE OR REPLACE FUNCTION fn_gerar_hash_geral()
  RETURNS text AS
$BODY$
DECLARE
	vtotal numeric;

BEGIN
	--alter table estrutur disable trigger tg_alterou_estrutur;
	--alter table estrutur disable trigger tg_alterou_estrutur2;
	--GERAR "HASH GERAL", considerando a limpeza de todos os hashes da base e recriação deles.
	--show work_mem;
	--limpa hash geral

	update estrutur set esthash = '' where esthash <> '';

	--remove se já exisitir depois cria uma temporária com os pais que possuem filho inativo (os que não são filho e estão inativos)
	drop table if exists pais_com_filho_inativo ;
	create temporary table pais_com_filho_inativo as (
		select unnest(
			(
				select array_agg(estproduto)
				from  connectby('estrutur', 'estproduto', 'estfilho', produto, 999, '<-') AS t(estproduto character(16), estfilho character(16), nivel int, caminho text)
				where nivel > 0
				
			)
		)
		produtos_com_filhos_inativos
		from produto 
		where prostatus = 'I'	
	);

	--gera o hash geral desconsiderando produtos inativos e produtos que possuem filho inativo
	select count(*) from (
		select --estproduto, 		ENGESTVER,		PRODGEN,		confatmed ,
			fn_gerar_hash(estproduto, ENGESTVER ,'S'/*salvar hash*/,'', PRODGEN, confatmed,'','') 
		from (
			select distinct on (estproduto) estproduto, prostatus, prodgen
			from estrutur 
			left join produto on (estproduto = produto)
			where esthash = ''
				and prostatus = 'A'
			order by estproduto
		) p
		left join (select confatmed from confpara limit 1)c on true
		left join (select ENGESTVER from ENGPARAM limit 1)e on true
		where estproduto not in (
			select produtos_com_filhos_inativos from pais_com_filho_inativo
		)
	)hashes_gerados into vtotal;

	drop table if exists pais_com_filho_inativo ;

	--alter table estrutur enable trigger tg_alterou_estrutur2;
	--alter table estrutur enable trigger tg_alterou_estrutur;

	return vtotal::text ;

	/*
	--Monta a estrutura do filho para cima (todos os pais)
	select * --array_agg(estproduto)
	from  connectby('estrutur', 'estproduto', 'estfilho', '04522311602      ', 999, '<-') AS t(estproduto character(16), estfilho character(16), nivel int, caminho text)
	--where nivel > 0

	--Monta a estrutura do pai para baixo
	select t.*, prostatus --array_agg(estproduto) pais 
	from  connectby('estrutur', 'estfilho', 'estproduto', '04522311602      ', 999, '->') AS t( estfilho character(16), estproduto character(16), nivel int, caminho text)
	left join produto on (estproduto=produto)
	--where nivel > 0
	*/

	--Conta a quantidade de produtos distintos sem hash
	--select distinct on (estproduto) estproduto from estrutur where esthash = '' order by estproduto




	 END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 1000;
ALTER FUNCTION fn_gerar_hash_geral()
  OWNER TO postgres;
