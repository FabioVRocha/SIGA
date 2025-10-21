-- Function: fn_cria_extension_tablefunc()

-- DROP FUNCTION fn_cria_extension_tablefunc();

CREATE OR REPLACE FUNCTION fn_cria_extension_tablefunc()
  RETURNS character varying AS
$BODY$
DECLARE
  
BEGIN 
	if not exists(SELECT extname FROM pg_extension where extname = 'tablefunc') then 
		--se o comando acima retornar vazio eh pq nao esta instalada a extension entao deve executar os 2 comandos abaixo.
		--como sabemos que na marzo foi criada a crosstab(text) manualmente e a tablefunc vai criar ela novamente, precisamos remove-la para nao dar erro no create tablefunc.
		--ESTA SITUACAO OCORREU NA BASE DA MARZO! TALVEZ NAO OCORRA EM NENHUMA OUTRA.
		drop function if exists crosstab(text);
		create extension if not exists tablefunc;
	end if;
	
	return 'OK';
	
EXCEPTION
	when SQLSTATE '58P01' then
		return 'ERRO: falta extension "tablefunc" na instalacao do postgres.';

END; 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 10;
ALTER FUNCTION fn_cria_extension_tablefunc()
  OWNER TO postgres;
