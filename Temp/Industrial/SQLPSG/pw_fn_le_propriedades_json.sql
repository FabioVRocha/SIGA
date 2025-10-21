-- Function: pw_fn_le_propriedades_json(text, text, text, text, boolean, text, boolean, integer)

-- DROP FUNCTION pw_fn_le_propriedades_json(text, text, text, text, boolean, text, boolean, integer);

CREATE OR REPLACE FUNCTION pw_fn_le_propriedades_json(json_texto text, propriedades text, separador_propriedades text, separador_registros text, incluir_nomes_de_propriedaes boolean, apelidos_de_propriedades text, incluir_repetidos boolean, indice_desejado integer)
  RETURNS text AS
$BODY$
DECLARE
    properties TEXT[] = regexp_split_to_array(propriedades, '\s*,\s*');
    aliases TEXT[] = regexp_split_to_array(COALESCE(apelidos_de_propriedades, propriedades), '\s*,\s*');  -- Trata aliases customizados ou usa as propriedades originais
    input_json JSON;
    result TEXT := '';
    element JSON;
    key TEXT;
    value TEXT;
    record_result TEXT;
    alias TEXT;
    index INT := 1;
    valor_anterior text := '';
    --itens json[];
    posicao_inicial integer;
    qtd_itens integer;
BEGIN
    
    --Se o usuário deseja um item específico, vai buscar apenas ele
    if indice_desejado > 0 then 
        posicao_inicial := indice_desejado - 1;
        qtd_itens := 1; 
    else 
        --Se o usuário deseja todos os itens, irá retornar no máximo um milhão de registros.
        posicao_inicial := 0;
        qtd_itens := 1000000; 
    end if;

    --converte a serialização recebida em objeto json
    input_json := json_texto::json;
    
    -- Loop through each element in the JSON array
    FOR element IN SELECT * FROM json_array_elements(input_json) OFFSET posicao_inicial LIMIT qtd_itens
    LOOP
        record_result := '';

        -- Loop through each key-value pair in the current JSON object
        FOR key, value IN SELECT * FROM json_each_text(element)
        LOOP
            -- Check if the key is in the properties array
            index := 1;
            
            FOR i IN 1..array_length(properties, 1)
            LOOP
                IF key = trim(properties[i]) THEN
                    alias := aliases[index];
                    
                    -- Concatenate the alias (if required) and value to the record_result string with a property separator
                    IF record_result != '' THEN
                        record_result := record_result || separador_propriedades;
                    END IF;

                    IF incluir_nomes_de_propriedaes THEN
                        record_result := record_result || alias || ': ' || value;
                    ELSE
                        record_result := record_result || value;
                    END IF;

                    EXIT; -- Exit loop once matched
                END IF;
                
                index := index + 1;
            END LOOP;

        END LOOP;

        --raise notice 'novo: %, antigo: %', record_result, valor_anterior;

         --Se for para incluir repetidos ou se o valor atual for diferente do anterior
        if incluir_repetidos or valor_anterior = '' or record_result <> valor_anterior then
            valor_anterior := record_result;
    
            -- Concatenate the record_result to the result string with a record separator
            IF record_result != '' THEN
                IF result != '' THEN
                    result := result || separador_registros;
                END IF;
                result := result || record_result;
            END IF;
        end if;

    END LOOP;

    RETURN result;
EXCEPTION WHEN others THEN 
    RETURN '';
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_le_propriedades_json(text, text, text, text, boolean, text, boolean, integer)
  OWNER TO postgres;
