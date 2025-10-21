CREATE OR REPLACE FUNCTION pw_fn_pedidos_do_controle_da_nota_json(p_controle BIGINT) RETURNS TEXT AS $$
DECLARE valor TEXT;
BEGIN if p_controle is null then raise notice 'retornando pois codigo e null';
return '';
end if;
/*Conforme sugerido pelo ChatGPT após algumas conversas...*/
SELECT --Transforma o array em json.
    array_to_json(
        --Junta todos os registros em um único array.
        array_agg(
            (
                --Transforma cada registro em um json
                SELECT row_to_json(view_pedido_de_venda)
            )
        )
    )
from (
        select *
        from pw_pedido_venda
        where pedidovenda_codigo_pk in (
                select notpedido
                from doctos
                where controle = p_controle
                    and p_controle is not null
                    and notpedido > 0
                union all
                select NTVPEDI            
                from ntvped    
                where NTVNOTA = p_controle                
                    and p_controle is not null
            )
    ) as view_pedido_de_venda INTO valor;
RETURN COALESCE(valor, '');
END;
$$ LANGUAGE plpgsql;
ALTER FUNCTION pw_fn_pedidos_do_controle_da_nota_json(BIGINT)
  OWNER TO postgres;