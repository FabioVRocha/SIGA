-- Function: fn_pesrlog_sequencia()

-- DROP FUNCTION fn_pesrlog_sequencia();

CREATE OR REPLACE FUNCTION fn_pesrlog_sequencia()
  RETURNS trigger AS
$BODY$
	BEGIN							
        IF (TG_OP = 'INSERT') THEN
            NEW.PRLSEQ := nextval('seq_lgpd_logs');
        END IF;
		RETURN NEW;
	END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_pesrlog_sequencia()
  OWNER TO postgres;
