    DROP TRIGGER IF EXISTS tg_projpedi_status_assistec ON projpedi;
    DROP TRIGGER IF EXISTS tg_projpedi_status_assistec ON projped1;
    DROP TRIGGER IF EXISTS fn_projpedi_status_assistec ON projped1;
    DROP TRIGGER IF EXISTS fn_projpedi_status_assistec ON projped1;
    CREATE OR REPLACE FUNCTION fn_projpedi_status_assistec()
      RETURNS trigger AS
    $BODY$
    declare
    	v_assistec integer;
    	v_integer integer;
    BEGIN

	If (TG_OP = 'INSERT') or (TG_OP = 'UPDATE') then
		If new.prjppeass = 'A' then
			v_assistec = new.prjpedido;
		End if;
	Else
		If old.prjppeass = 'A' then
			v_assistec = old.prjpedido;
		End if;
	End if;
    
	v_integer = (select fn_status_assistec(v_assistec));
	
	Return Null;
	
    END;
    $BODY$
      LANGUAGE plpgsql VOLATILE
      COST 100;
    ALTER FUNCTION fn_projpedi_status_assistec()
      OWNER TO postgres;