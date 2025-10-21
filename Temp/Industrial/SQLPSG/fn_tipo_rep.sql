-- Function: fn_tipo_rep()

--DROP FUNCTION fn_tipo_rep();

CREATE OR REPLACE FUNCTION fn_tipo_rep()
  RETURNS trigger AS
$BODY$
declare
	tipo_vendedor character(1);
BEGIN	
	if TG_OP <> 'DELETE' then		
            Select ventiprel into tipo_vendedor from vendedor Where vendedor = new.vendedor;
            new.coptiprep = tipo_vendedor;
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
ALTER FUNCTION fn_tipo_rep() SET search_path=public, pg_temp;

ALTER FUNCTION fn_tipo_rep()
  OWNER TO postgres;