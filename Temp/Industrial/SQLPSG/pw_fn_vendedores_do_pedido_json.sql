-- Function: pw_fn_vendedores_do_pedido_json(integer)

-- DROP FUNCTION pw_fn_vendedores_do_pedido_json(integer);

CREATE OR REPLACE FUNCTION pw_fn_vendedores_do_pedido_json(p_pedido integer)
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
                ORDER BY pedidovendedor_codigo_do_pedido_pk ASC, pedidovendedor_codigo_do_vendedor_fk                
            )
        )
    FROM 
        (
	SELECT c.coppedido AS pedidovendedor_codigo_do_pedido_pk,
            c.copseq AS pedidovendedor_sequencia_do_Pedido_pk,
            c.vendedor AS pedidovendedor_codigo_do_vendedor_fk
        FROM comiped c
    ) pw_pedido_vendedor
    left join 
        pw_vendedor on (pedidovendedor_codigo_do_vendedor_fk = vendedor_codigo_pk)
   
    --A funcao pode receber o codigo a ser filtrado por parametro
    WHERE  pedidovendedor_codigo_do_pedido_pk = p_pedido
    INTO valor;

    RETURN COALESCE(valor, '');

END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_vendedores_do_pedido_json(integer)
  OWNER TO postgres;
