DROP TRIGGER IF EXISTS tg_ordem_status_assistec ON ordem;
DROP TRIGGER IF EXISTS fn_ordem_status_assistec ON ordem;
DROP TRIGGER IF EXISTS fn_ordem_status_assistec ON ordem;
    CREATE OR REPLACE FUNCTION fn_ordem_status_assistec()
      RETURNS trigger AS
    $BODY$
    declare
    	v_ordem integer;
    	v_assistec integer;
    	v_integer integer;
    BEGIN
    
    	If (TG_OP = 'INSERT') or (TG_OP = 'UPDATE') then
    		v_ordem = new.ordem;
    	Else
    		v_ordem = old.ordem;
    	End if;
    
    	v_assistec = (select ac.acaorasco from acaorde4 ac where ac.acaoorde = v_ordem limit 1);
    
    	v_integer = (select fn_status_assistec(v_assistec));
    	
    	Return Null;
    	
    END;
    $BODY$
      LANGUAGE plpgsql VOLATILE
      COST 100;
    ALTER FUNCTION fn_ordem_status_assistec()
      OWNER TO postgres;