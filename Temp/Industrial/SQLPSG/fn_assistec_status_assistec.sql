    DROP TRIGGER IF EXISTS tg_assistec_status_assistec ON assistec;
    DROP TRIGGER IF EXISTS fn_assistec_status_assistec ON assistec;
    DROP TRIGGER IF EXISTS fn_assistec_status_assistec ON assistec;
    CREATE OR REPLACE FUNCTION fn_assistec_status_assistec()
      RETURNS trigger AS
    $BODY$
    declare
    	v_assistec integer;
    	v_integer integer;
    BEGIN
    
    	If (TG_OP = 'INSERT') or (TG_OP = 'UPDATE') then
    		v_assistec = new.assistec;
    	Else
    		v_assistec = old.assistec;
    	End if;
    
    	v_integer = (select fn_status_assistec(v_assistec));
    	Return Null;
    END;
    $BODY$
      LANGUAGE plpgsql VOLATILE
      COST 100;
    ALTER FUNCTION fn_assistec_status_assistec()
      OWNER TO postgres;