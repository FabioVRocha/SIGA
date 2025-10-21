--drop function fn_get_elementos_ordenados(bigint[], text[])
CREATE OR REPLACE FUNCTION fn_get_elementos_ordenados(
    arr_valores bigint[], 
    arr_textos text[]
)
RETURNS text AS $$
	select coalesce(ARRAY_TO_STRING(array_agg(arr_textos[i] ORDER BY arr_valores[i]), '-'), '') 
	FROM generate_subscripts(arr_valores, 1) AS i
	WHERE arr_valores[i] > 0 and arr_textos[i] <> '' and arr_textos[i] is not null;      
$$ LANGUAGE sql IMMUTABLE;
ALTER FUNCTION fn_get_elementos_ordenados(bigint[], text[]) OWNER TO postgres;