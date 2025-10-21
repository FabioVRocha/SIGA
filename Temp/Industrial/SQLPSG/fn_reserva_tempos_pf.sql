-- Function: fn_reserva_tempos_pf()

-- DROP FUNCTION fn_reserva_tempos_pf();

CREATE OR REPLACE FUNCTION fn_reserva_tempos_pf()
  RETURNS trigger AS
$BODY$
begin
	if (TG_OP = 'UPDATE') then
		update ordens set maquina_reserva_tempos = new.rprmaq where ordem = new.rprordem::char(10) and sequencia = new.rprproce::char(10);
		return new;
	end if;
	if (TG_OP = 'DELETE') then
		update ordens set acao = '3' where ordem = old.rprordem::char(10) and sequencia = old.rprproce::char(10);
		return old;
	end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_reserva_tempos_pf() SET search_path=public, pg_temp;

ALTER FUNCTION fn_reserva_tempos_pf()
  OWNER TO postgres;
