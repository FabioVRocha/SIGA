CREATE OR REPLACE FUNCTION fn_get_session_var(p_variavel character varying)
  RETURNS character varying AS
$BODY$
DECLARE
BEGIN 
	/*[12/08/2022, 3770822, Ricardo K] Fix performance hash marzo.
	Esta funcao serve para LER "variaveis de sessao" que utilizamos na trigger da tabela estrutur para armazenar o usuario logado.
	Anterior ao postgres 9.3 era necessario declarar as "opcoes customizadas" no arquivo de configuracao do postgres entao para evitar isso foi utilizada
	uma tabela temporaria, que causou uma degradacao de performance tremenda 4min -> 75min.
	Entao nesta OS foi tratado para que versoes >= 9.3 utilizem as prop customizadas que fez com que 4min -> 8min.*/
	
	if substring(version(), 12, 1 + position('.' in substring(version(), 12)))::numeric >= 9.3 then
		--A partir do 9.3 pode ser usado dessa forma
		RAISE NOTICE 'EXECUTOU 9.3';
		return current_setting(p_variavel);
	else
		RAISE NOTICE 'EXECUTOU MENOR QUE 9.3';
		if exists(select 1 from information_schema.tables where table_name='variaveis_sessao' and table_type = 'LOCAL TEMPORARY')  then
			if exists(select 1 from variaveis_sessao where variavel = p_variavel) then
			
				return (select valor from variaveis_sessao where variavel = p_variavel limit 1);

			end if;
		end if;

		return null;
	end if;
EXCEPTION
	when SQLSTATE '42704' then
		return NULL;	

END; 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 10;
ALTER FUNCTION fn_get_session_var(character varying)
  OWNER TO postgres;