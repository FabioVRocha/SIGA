-- Function: fn_cotacao_tipo_pedido_compra(bigint, integer)

-- DROP FUNCTION fn_cotacao_tipo_pedido_compra(bigint, integer);

CREATE OR REPLACE FUNCTION fn_cotacao_tipo_pedido_compra(p_compra_item bigint, p_compra_cabec integer)
  RETURNS character AS
$BODY$
DECLARE
    v_comtipo text;
    v_compra integer;
begin
	if p_compra_item > 0 then
		v_compra = p_compra_item;
	else
		v_compra = p_compra_cabec;
	end if;
	
	select
		comtipo into v_comtipo
	from compra c
	where c.compra = v_compra;

	return coalesce(v_comtipo, '');
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_cotacao_tipo_pedido_compra(bigint, integer) SET search_path=public, pg_temp;

ALTER FUNCTION fn_cotacao_tipo_pedido_compra(bigint, integer)
  OWNER TO postgres;
