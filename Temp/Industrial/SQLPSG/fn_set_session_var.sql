CREATE OR REPLACE FUNCTION fn_set_session_var(p_variavel varchar, p_valor varchar)
  RETURNS void AS
$BODY$
DECLARE
  v_tabela text;  
BEGIN
	/*[12/08/2022, 3770822, Ricardo K] Fix performance hash marzo.
	Esta funcao serve para GRAVAR "variaveis de sessao" que utilizamos na trigger da tabela estrutur para armazenar o usuario logado.
	Anterior ao postgres 9.3 era necessario declarar as "opcoes customizadas" no arquivo de configuracao do postgres entao para evitar isso foi utilizada
	uma tabela temporaria, que causou uma degradacao de performance tremenda 4min -> 75min.
	Entao nesta OS foi tratado para que versoes >= 9.3 utilizem as prop customizadas que fez com que 4min -> 8min.*/

	if substring(version(), 12, 1 + position('.' in substring(version(), 12)))::numeric >= 9.3 then
		--A partir do 9.3 pode ser utilizado desta forma. Antes do 9.3 as variaveis customizadas precisam ser declaradas no postgresql.conf.
		perform set_config(p_variavel, p_valor, FALSE);
	else
		--antes do 9.3, deve ser verificado se existe tabela temporaria e dropar ela para ser recriada.
		v_tabela = replace(p_variavel, '.', '_');
		if not exists(select * from information_schema.tables where table_name='variaveis_sessao' and table_type = 'LOCAL TEMPORARY') then
			execute 'create temporary table variaveis_sessao(variavel text, valor text)';
		else
			if exists(select 1 from variaveis_sessao where variavel = p_variavel) then
				execute 'delete from variaveis_sessao where variavel = $1' using p_variavel;
			end if;
		end if;

		insert into variaveis_sessao(variavel,valor) values (p_variavel, p_valor);
	end if;
	
END; 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 10;
ALTER FUNCTION fn_set_session_var(character varying, character varying)
  OWNER TO postgres;