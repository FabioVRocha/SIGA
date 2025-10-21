-- Function: fn_tipocontato_status()

-- DROP FUNCTION fn_tipocontato_status();

CREATE OR REPLACE FUNCTION fn_tipocontato_status()
  RETURNS trigger AS
$BODY$
begin
        if (TG_OP = 'INSERT' or TG_OP = 'UPDATE') then
	        IF (NEW.TPCONS = 'A' ) THEN
	           NEW.TPCONL = 'Ativo';
	        END IF;
	        IF (NEW.TPCONS = 'I' ) THEN
	           NEW.TPCONL = 'Inativo';
	        END IF;       
	        RETURN NEW;
       else
       		return old;
       end if;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_tipocontato_status() SET search_path=public, pg_temp;

ALTER FUNCTION fn_tipocontato_status()
  OWNER TO postgres;
