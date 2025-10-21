-- Function: fn_visita_conceito()

-- DROP FUNCTION fn_visita_conceito();

CREATE OR REPLACE FUNCTION fn_visita_conceito()
  RETURNS trigger AS
$BODY$
BEGIN        
        IF (NEW.VISCONCEI = 'A' ) THEN
           NEW.VISLCONC = '-------';
        END IF;
        IF (NEW.VISCONCEI = 'O' ) THEN
           NEW.VISLCONC = 'Ótimo';          
        END IF;
       IF (NEW.VISCONCEI = 'B' ) THEN
           NEW.VISLCONC = 'Bom';
        END IF;
        IF (NEW.VISCONCEI = 'E' ) THEN
           NEW.VISLCONC = 'Regular';          
        END IF;
        IF (NEW.VISCONCEI = 'R' ) THEN
           NEW.VISLCONC = 'Ruim';          
        END IF;       

	RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_visita_conceito() SET search_path=public, pg_temp;

ALTER FUNCTION fn_visita_conceito()
  OWNER TO postgres;
