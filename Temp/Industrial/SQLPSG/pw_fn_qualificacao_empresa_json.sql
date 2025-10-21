-- Function: pw_fn_qualificacao_empresa_json(integer)

-- DROP FUNCTION pw_fn_qualificacao_empresa_json(integer);


CREATE OR REPLACE FUNCTION pw_fn_qualificacao_empresa_json(p_empresa integer)
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
                    SELECT row_to_json(pw_qualificacao)
                )
                --Pode definir uma condicao para ordenacao dos registros dentro do array
                ORDER BY qualificacao_codigo_pk ASC
            )
        )
    FROM 
        (
        SELECT q.empresa AS qualif_empresa_codigo_pk,
            q.qualif AS qualif_codigo_pk 
        From emquali q    
    ) pw_qualifica_empresa
    left join 
        pw_qualificacao on (qualif_codigo_pk  = qualificacao_codigo_pk)
   
    --A funcao pode receber o codigo a ser filtrado por parametro
    WHERE qualif_empresa_codigo_pk = p_empresa
    INTO valor;

    RETURN COALESCE(valor, '');

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_qualificacao_empresa_json(integer)
  OWNER TO postgres;

