-- Function: fn_app02(character, character varying, integer)

-- DROP FUNCTION fn_app02(character, character varying, integer);

CREATE OR REPLACE FUNCTION fn_app02(cusuario character, cjson character varying, nfilial integer)
  RETURNS void AS
$BODY$ -- Busca dados das ordens e joga no temporario UMAPPHORAS.
DECLARE
  cjsontxt json;
  cjsontxt1 json;
  cjsontxt2 json;
  cOrdemProcesso char(13);
  nn numeric(3);
  cDeposito integer;
  jsonTam numeric(5);
  cUsuarioJson char(10);
  cDataInicial date;
  cDataFinal date;
  cHoraInicial numeric(5,2);
  cHoraFinal numeric(5,2);
  cHoraTotal numeric(11,6);
  cProcesso char(3);
  cOperacao char(20);
  cMaquina char(5);
  cFase numeric(2);
  cQuantidade numeric(15,4);
  cMotivo char(2);
  cMaterial char(16);
  cLoteExecucao char(10);
  cNumReserva numeric(10);
  cProduto char(16);
  cTipomovimento numeric(2);
  cDocumento char(8);
  cObservacao char(100);
  cFuncionario numeric(5);
  cLoteProducao char(6);
  cFormaPassagem char(1);
  cFuncioariosAdicionais json;
  cFuncioariosAdicionaisConc text;
BEGIN 
   nn = 1;
   cjsontxt = cjson;
   cusuario = replace(cusuario, '"', '');
   delete from umapphor where umpousu = cusuario; --Limpa o temporario
   --Busca as Informacoes do JSON
   jsonTam = json_array_length(cjsontxt::json -> 'results'); --Busca Quantas posicoes tem o JSON
   for cjsontxt2 in (select * from json_array_elements(cjsontxt::json -> 'results') ) loop --Faz um laco para ler todas as posicoes
	if nn <= jsonTam then
	   cOrdemProcesso = cjsontxt2 -> 'Ordem'; -- numerico nao vira entre aspas, entao nao preciso de dois ">>"
	   cDeposito = cjsontxt2      -> 'Deposito';
	   cUsuarioJson = cjsontxt2   ->> 'Usuario';
	   cDataInicial = cjsontxt2   ->> 'DataInicial';
	   cDataFinal   = cjsontxt2   ->> 'DataFinal';
	   cHoraInicial = cjsontxt2   -> 'HoraInicial';
	   cHoraFinal = cjsontxt2     -> 'HoraFinal';
	   cHoraTotal = cjsontxt2     -> 'HoraTotal';
	   cProcesso = cjsontxt2      ->> 'Processo';
	   cOperacao = cjsontxt2      ->> 'Operacao';
	   cMaquina = cjsontxt2       ->> 'Maquina';
	   cFase = cjsontxt2          -> 'Fase';
	   cQuantidade = cjsontxt2    -> 'Quantidade';
	   cMotivo = cjsontxt2        ->> 'Motivo';
	   cMaterial = cjsontxt2      ->> 'Material'; 	   
	   cLoteExecucao = cjsontxt2  ->> 'LoteExecucao';
	   cNumReserva = cjsontxt2    -> 'Numreserva';
	   cProduto = cjsontxt2       ->> 'Produto';
	   cTipomovimento = cjsontxt2 -> 'Tipomovimento';
	   cDocumento = cjsontxt2     ->> 'Documento';
	   cObservacao = cjsontxt2    ->> 'Observacao';
	   cFuncionario = cjsontxt2    -> 'Funcionario';
	   cLoteProducao = cjsontxt2  ->> 'Lote';
	   cFormaPassagem = cjsontxt2  ->> 'FormaPassagem';
	   cFuncioariosAdicionais = cjsontxt2 ->> 'FuncionariosAdicionais';
	   for cjsontxt1 in (select * from json_array_elements(cFuncioariosAdicionais::json) ) loop --Faz um laco para ler todas as posicoes
		    if cFuncioariosAdicionaisConc is null or cFuncioariosAdicionaisConc = '' then
		   		cFuncioariosAdicionaisConc = (cjsontxt1 -> 'Funcionario')::text || ';';
	   		else
	   			cFuncioariosAdicionaisConc = cFuncioariosAdicionaisConc || (cjsontxt1 -> 'Funcionario')::text || ';';
	   		end if;
	   end loop;
	   --Grava o temporario para o usuario dos parametros
	   insert into umapphor(umpousu, umposeq, umpoordpro, umpoproc, umpodepo, umpoqtde, umpotxt, umpoappusu, umpodtini, umpohrini, umpoopera, umpomaq, umpofase, umpodtfim, umpohrfim, umpohrtot, umpomoti, umpomateri, umpolotexe, umponumres, umprodut, umpotpmov, umpodocum, umpoobserv,umpofuncio, umpolotpro, umpoforpas, umpoadfunc) values
	       (cusuario, nn, cOrdemProcesso, cProcesso, cDeposito, cQuantidade, '', cUsuarioJson, cDataInicial, cHoraInicial, cOperacao, cMaquina, cFase, cDataFinal, cHoraFinal, cHoraTotal, cMotivo, cMaterial, cLoteExecucao, cNumReserva, cProduto, cTipomovimento, cDocumento, cObservacao,cFuncionario, cLoteProducao, cFormaPassagem, cFuncioariosAdicionaisConc);
	else
	   exit;
	end If;
	nn = nn + 1;
   end loop;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_app02(character, character varying, integer) SET search_path=public, pg_temp;

ALTER FUNCTION fn_app02(character, character varying, integer)
  OWNER TO postgres;
