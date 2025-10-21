    DROP TRIGGER IF EXISTS tg_expsimpl_status_assistec ON prjexsi1;
    DROP TRIGGER IF EXISTS fn_expsimpl_status_assistec ON prjexsi1;
    DROP TRIGGER IF EXISTS fn_expsimpl_status_assistec ON prjexsi1; 
    CREATE OR REPLACE FUNCTION fn_expsimpl_status_assistec()
      RETURNS trigger AS
    $BODY$
    declare
    	v_assistec integer;
    	v_integer integer;
    BEGIN
	If (TG_OP = 'INSERT') or (TG_OP = 'UPDATE') then
		If new.prjesstip = 'A' then
			v_assistec = new.prjessepa;
		End if;
	Else
		If old.prjesstip = 'A' then
			v_assistec = old.prjessepa;
		End if;
	End if;
    
	v_integer = (select fn_status_assistec(v_assistec));
	
	Return Null;
	
    END;
    $BODY$
      LANGUAGE plpgsql VOLATILE
      COST 100;
    ALTER FUNCTION fn_expsimpl_status_assistec()
      OWNER TO postgres;