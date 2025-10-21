-- Function: fn_app01(character, character varying, integer)

-- DROP FUNCTION fn_app01(character, character varying, integer);

CREATE OR REPLACE FUNCTION fn_app01(cusuario character, cjson character varying, nfilial integer)
  RETURNS void AS
$BODY$ -- Busca dados das ordens e joga no temporario UMAPPHORAS.
DECLARE
  cjsontxt json;
  cjsontxt2 json;
  cOrdemProcesso char(13);
  nn numeric(3);
  cDeposito integer;
  jsonTam numeric(5);
  cUsuarioJson char(10);
  cMaquina char(5);
  cData Date;
  cLoteExecucao char(10);
  cFuncionario numeric(5);
BEGIN 
   nn = 1;
   cjsontxt = cjson;
   cusuario = replace(cusuario, '"', '');
   delete from umapphor where umpousu = cusuario; --Limpa o temporario
   --Busca as Informacoes do JSON
   jsonTam = json_array_length(cjsontxt::json -> 'results'); --Busca Quantas posicoes tem o JSON
   for cjsontxt2 in (select * from json_array_elements(cjsontxt::json -> 'results') ) loop --Faz um laco para ler todas as posicoes
	if nn <= jsonTam then
	   cOrdemProcesso = cjsontxt2 ->> 'CodigoBarras'; --Dois >> para buscar o texto, se colocar um > busca entre aspas duplas e tem que fazer replace
	   If character_length(cOrdemProcesso) = 0 then
		cOrdemProcesso = cjsontxt2 -> 'Ordem';
	   End If;
	   cDeposito = cjsontxt2 ->> 'Deposito';
	   cUsuarioJson = cjsontxt2 ->> 'Usuario';
	   cMaquina = cjsontxt2 ->> 'Maquina';
	   cLoteExecucao = cjsontxt2 ->> 'LoteExecucao';
	   cFuncionario = cjsontxt2    -> 'Funcionario';

	   --Grava o temporario para o usuario dos parametros
	   insert into umapphor(umpousu, umposeq, umpoordpro, umpoproc, umpodepo, umpoqtde, umpotxt, umpoappusu, umpomaq, umpolotexe,umpofuncio) values
	       (cusuario, nn, cOrdemProcesso, '', cDeposito, 0, '', cUsuarioJson, cMaquina, cLoteExecucao,cFuncionario);
	else
	   exit;
	end If;
	nn = nn + 1;
   end loop;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_app01(character, character varying, integer) SET search_path=public, pg_temp;

ALTER FUNCTION fn_app01(character, character varying, integer)
  OWNER TO postgres;
