-- Function: pw_fn_vendedor_empresa_json(integer)

-- DROP FUNCTION pw_fn_vendedor_empresa_json(integer);

CREATE OR REPLACE FUNCTION pw_fn_vendedor_empresa_json(p_empresa integer)
  RETURNS text AS
$BODY$
DECLARE
    valor TEXT;
BEGIN 
    /*Conforme sugerido pelo ChatGPT apos algumas conversas...*/
    SELECT 
        --Transforma o array em json.
        array_to_json( 
            --Junta todos os registros em um unico array.
            array_agg(
                (
                    --Transforma cada registro em um json
                    SELECT row_to_json(pw_vendedor)
                )
                --Pode definir uma condicao para ordenacao dos registros dentro do array
                ORDER BY vendedor_empresa_codigo_pk ASC, vendedor_vendedor_codigo_pk                 
            )
        )
    FROM 
        (
        SELECT v.cmempresa AS vendedor_empresa_codigo_pk,
            v.cmerepcod AS vendedor_vendedor_codigo_pk 
        From cmempre2 v    
    ) pw_vendedor_empresa
    left join 
        pw_vendedor on ( vendedor_vendedor_codigo_pk  = vendedor_codigo_pk)
   
    --A funcao pode receber o codigo a ser filtrado por parametro
    WHERE vendedor_empresa_codigo_pk = p_empresa
    INTO valor;

    RETURN COALESCE(valor, '');

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_vendedor_empresa_json(integer)
  OWNER TO postgres;


select pw_fn_vendedor_empresa(10)