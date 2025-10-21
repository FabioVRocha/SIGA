    DROP TRIGGER IF EXISTS tg_acaorde4_status_assistec ON acaorde4;
    DROP TRIGGER IF EXISTS fn_acaorde4_status_assistec ON acaorde4;
    DROP TRIGGER IF EXISTS fn_acaorde4_status_assistec ON acaorde4;
    CREATE OR REPLACE FUNCTION fn_acaorde4_status_assistec()
      RETURNS trigger AS
    $BODY$
    declare
    	v_assistec integer;
    	v_integer integer;
    BEGIN
    
    	If (TG_OP = 'INSERT') or (TG_OP = 'UPDATE') then
    		v_assistec = new.acaorasco;
    	Else
    		v_assistec = old.acaorasco;
    	End if;
    
    	v_integer = (select fn_status_assistec(v_assistec));
    	
    	Return Null;
    END;
    $BODY$
      LANGUAGE plpgsql VOLATILE
      COST 100;
    ALTER FUNCTION fn_acaorde4_status_assistec()
      OWNER TO postgres;