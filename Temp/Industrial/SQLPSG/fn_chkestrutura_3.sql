-- Function: fn_chkestrutura_3(character, text[], character, integer, integer, text)

-- DROP FUNCTION fn_chkestrutura_3(character, text[], character, integer, integer, text);

CREATE OR REPLACE FUNCTION fn_chkestrutura_3(
    poriginal character,
    ppercorridos text[],
    plerestrutura character,
    precursao integer,
    pnivel integer,
    pcaminho text)
  RETURNS text[] AS
$BODY$
DECLARE

tmp_record record;
entrada text[];
erro text;

BEGIN

--Raise notice '%', poriginal::text||' ARRAY INICIO '||plerestrutura::text ||' : '|| array_to_string(ppercorridos, ', ');

--sai fora se o produto ja foi percorrido
if plerestrutura::text = any(ppercorridos) then
	Raise notice '%', plerestrutura::text||' JA PERCORRIDO, SAINDO ';
	return ppercorridos;
end if;

--ADICIONA O ITEM ATUAL NO ARRAY DE JA PERCORRIDOS.
ppercorridos = ARRAY_APPEND(ppercorridos, plerestrutura::text);
entrada = ppercorridos;

--itera todos os filhos do produto recebido se ele ainda nao foi percorrido
for tmp_record in (select estproduto, estfilho, proorigem from estrutur, produto where estproduto = plerestrutura and estrutur.estproduto = produto.produto ) 
loop
  
  If tmp_record.estfilho =  any(ppercorridos)  then

     --Raise notice '%', poriginal::text||' #2filho ja percorrido# '||plerestrutura::text || ' rec:'||precursao||' nvl:'||pnivel||' | '||pcaminho || '->' || tmp_record.estfilho;
	--somente sera erro se o produto ja apareceu no caminho atual, senao soh significa que um filhpo anterior passou por ele
	if pcaminho::text ~ ('\\y'||trim(tmp_record.estfilho)||'\\y')::text then 
		erro := 'ERRO REFERENCIA CIRCULAR! Partindo de ' || poriginal::text||' o produto '||tmp_record.estfilho::text || ' foi encontrado mais de uma vez! recursao:'||precursao||' nivel:'||pnivel||' | '||pcaminho || '->' || tmp_record.estfilho;
		Raise notice '%', erro;
		ppercorridos := ARRAY[erro];
	end if;
     return ppercorridos;
  Else  
     If tmp_record.proorigem = 'F' then
	if precursao = 0 then
		precursao = precursao + 1;
	end if;

        ppercorridos = fn_chkestrutura_3(poriginal, entrada, tmp_record.estfilho, precursao, pnivel + 1, pcaminho || '->' || tmp_record.estfilho);

	--raise notice '%', 'ARRAY NA SAIDA: '||array_to_string(ppercorridos, ', '); 

        if array_to_string(ppercorridos, ', ') like 'ERRO%' then
		raise notice '%', 'SAINDO POIS RETORNOU ERRO';
		return ppercorridos;
	end if;
     End If;
  End If;  
end loop;  
return ppercorridos;      
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_chkestrutura_3(character, text[], character, integer, integer, text)
  OWNER TO postgres;
