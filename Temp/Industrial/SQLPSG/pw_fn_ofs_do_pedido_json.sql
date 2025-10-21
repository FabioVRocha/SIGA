
--DROP FUNCTION pw_fn_ofs_do_pedido_json(integer, integer);

CREATE OR REPLACE FUNCTION pw_fn_ofs_do_pedido_json(p_pedido integer, p_seqped integer)
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
                    SELECT row_to_json(pw_ordem)
                )
                --Pode definir uma condicao para ordenacao dos registros dentro do array
                ORDER BY pedidoof_ordem_codigo_pk ASC, pedidoof_pedido_codigo_pk                
            )
        )
    FROM 
        (
        SELECT a.acaoorde AS pedidoof_ordem_codigo_pk,
            a.acaorped AS pedidoof_pedido_codigo_pk,
            a.acaorseq AS pedidoof_sequencia_produto_pk,
            a.acaorpro AS pedidoof_produto_codigo_fk            
	FROM acaorde3 a where a.acaorseq = p_seqped 
    ) pw_pedido_of
    left join 
        pw_ordem on (pedidoof_ordem_codigo_pk = ordem_codigo_pk and pedidoof_produto_codigo_fk = ordem_produto_codigo_fk)
    left join 
        pw_pedido_venda on (pedidoof_pedido_codigo_pk = pedidovenda_codigo_pk)       
   
    --A funcao pode receber o codigo a ser filtrado por parametro
    WHERE  pedidoof_pedido_codigo_pk = p_pedido and pedidovenda_produto_codigo_fk = ordem_produto_codigo_fk
    INTO valor;

    RETURN COALESCE(valor, '');
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_ofs_do_pedido_json(integer)
  OWNER TO postgres;

--SELECT pw_fn_ofs_do_Pedido_json(107286)

--select * from pedprodu Where pedido = 107286