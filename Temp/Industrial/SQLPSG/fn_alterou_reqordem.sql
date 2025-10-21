-- Function: fn_alterou_reqordem()

-- DROP FUNCTION fn_alterou_reqordem();

CREATE OR REPLACE FUNCTION fn_alterou_reqordem()
  RETURNS trigger AS
$BODY$
declare
	v_data date;
	v_horario varchar; 
	v_ip varchar;
	v_usuario varchar;
BEGIN	
	if TG_OP <> 'DELETE' then		
		v_data = (select current_date);
		v_horario = (select substring(current_time::text, 1, 8)); 

		v_usuario = fn_get_session_var('industrial.usuario');

		--Se o usuario nao estiver definido na sessao, pega o final do IP.
		if v_usuario is null then
			v_ip = (select inet_client_addr()::varchar);
			v_usuario = substring(v_ip, length(v_ip)- 9);
		end if;
		
		NEW.REQDTALT = v_data;
		NEW.REQHRALT = v_horario;
		NEW.REQUSALT = v_usuario;
	end if;

	if TG_OP = 'DELETE' then
		RETURN OLD;
	else
		RETURN NEW;
	end if;
		
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_alterou_reqordem() SET search_path=public, pg_temp;

ALTER FUNCTION fn_alterou_reqordem()
  OWNER TO postgres;