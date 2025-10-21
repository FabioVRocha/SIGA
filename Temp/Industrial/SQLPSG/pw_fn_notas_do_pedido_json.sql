CREATE OR REPLACE FUNCTION pw_fn_notas_do_pedido_json(
    p_pedido integer
) RETURNS TEXT AS $$
DECLARE
    valor TEXT;
BEGIN
 
    if p_pedido is null then
        raise notice 'retornando pois codigo eh null';
        return '';
    end if;

    /*Conforme sugerido pelo ChatGPT p�s algumas conversas...*/
    SELECT 
        --Transforma o array em json.
        array_to_json( 
            --Junta todos os registros em um �nico array.
            array_agg(
                (
                    --Transforma cada registro em um json
                    SELECT row_to_json(pw_faturamento)
                )
                --Pode definir uma condi��o para ordena��o dos registros dentro do array
                ORDER BY notaspedidos_pedido ASC                
            )
        )
    FROM 
        (
	Select * from 
	(
		Select CONTROLE as notaspedidos_controle, notdocto, case when notpedido > 0 then notpedido
			else
				ntvpedi 
			end as notaspedidos_pedido
		from DOCTOS 
		left join ntvped on (controle = ntvnota)
			where nullif(trim(notdocto),'') is not null
	)as sub
	Where notaspedidos_pedido > 0
	)  pw_notas_pedidos
    left join 
        pw_faturamento on (notaspedidos_controle = faturamento_controle)
   
    --A fun��o poder� receber o c�digo a ser filtrado por par�mentro
    WHERE notaspedidos_pedido = p_pedido and p_pedido is not null
    INTO valor;

    RETURN COALESCE(valor, '');

END;

$$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION pw_fn_notas_do_pedido_json(integer)
  OWNER TO postgres;