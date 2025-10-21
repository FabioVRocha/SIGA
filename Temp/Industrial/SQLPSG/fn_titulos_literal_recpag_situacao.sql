-- Function: fn_titulos_literal_recpag_situacao()

-- DROP FUNCTION fn_titulos_literal_recpag_situacao();

CREATE OR REPLACE FUNCTION fn_titulos_literal_recpag_situacao()
  RETURNS trigger AS
$BODY$ 
 BEGIN 
	IF (NEW.titrecpag = 'R') THEN 
		NEW.titlitrp = 'A Receber'; 
	ELSE 
		IF (NEW.titrecpag = 'P') THEN 
			NEW.titlitrp = 'A Pagar'; 
		END IF; 
	END IF;  
	IF (NEW.titvltotal <= NEW.titvlpag) THEN 
		NEW.titlitsit = 'Quitado'; 
	ELSE 
		IF (NEW.titvltotal > NEW.titvlpag AND NEW.titvlpag > 0) THEN 
			NEW.titlitsit = 'Quitado Parcial'; 
		ELSE 
			IF (NEW.titvlpag = 0) THEN 
				NEW.titlitsit = 'Aberto'; 
			END IF; 
		END IF; 
	END IF;  
	RETURN NEW;
 END; 
 $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_titulos_literal_recpag_situacao()
  OWNER TO postgres;
