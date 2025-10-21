-- Function: fn_schema_fisica()

-- DROP FUNCTION fn_schema_fisica();

CREATE OR REPLACE FUNCTION fn_schema_fisica()
  RETURNS void AS
$BODY$ 
DECLARE 
    current_db_name TEXT;
BEGIN    

    SELECT current_database() INTO current_db_name;
    EXECUTE 'ALTER DATABASE ' || current_db_name || ' SET search_path TO public, temp, fisica';
    --alter database  SET search_path TO public, temp, fisica; --Deve ser feito de forma dinâmica, conforme acima, para criar na base executada.

    IF not exists(SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'fisica') THEN
        --cria o schema onde estara a tabela UMESTRUT fisica
        create schema fisica;
    END IF;
    
    IF not exists(SELECT table_name FROM information_schema.tables WHERE table_schema = 'fisica' AND table_name = 'umestrut') THEN
        RAISE NOTICE 'Criando tabela "umestrut" no esquema fisica.';
        
        --Cria a tabela umestrut da mesma forma que no objeto UMESTRUT
        CREATE TABLE fisica.umestrut
		(
		  umestusuar character(10) NOT NULL,
		  umestnivel character(200) NOT NULL,
		  umestprodu character(16),
		  umestquant numeric(16,6),
		  umestmedid character(1),
		  umevlrnive bigint,
		  umestpesof numeric(11,3),
		  umestcompr numeric(9,2),
		  umestlargu numeric(9,2),
		  umestprono character(50),
		  umeorigem character(1),
		  umefantasm character(1),
		  umeunidade character(2),
		  umestquato numeric(14,4),
		  umestreqau character(1),
		  umestfilhf character(1),
		  umefase smallint,
		  umestcusre numeric(14,4),
		  umeqteng numeric(11,4),
		  umeqtentot numeric(14,4),
		  umestpropa character(16),
		  umestver bigint,
		  umestcnive character(10),
		  umestmarca character(1),
		  umestdpro character(50),
		  umestdppa character(50),
		  CONSTRAINT umestrut_pkey PRIMARY KEY (umestusuar, umestnivel)
		)
		WITH (
		  OIDS=FALSE
		);
		ALTER TABLE fisica.umestrut
		  OWNER TO postgres;
		
		-- Index: iumestr1
		
		-- DROP INDEX iumestr1;
		
		CREATE INDEX iumestr1
		  ON fisica.umestrut
		  USING btree
		  (umestusuar, umestcompr, umestnivel);
		
		-- Index: iumestr2
		
		-- DROP INDEX iumestr2;
		
		CREATE INDEX iumestr2
		  ON fisica.umestrut
		  USING btree
		  (umestusuar, umestpesof, umevlrnive);
		
		-- Index: iumestr3
		
		-- DROP INDEX iumestr3;
		
		CREATE INDEX iumestr3
		  ON fisica.umestrut
		  USING btree
		  (umestusuar, umestpesof, umestnivel);
		
		-- Index: iumestr4
		
		-- DROP INDEX iumestr4;
		
		CREATE INDEX iumestr4
		  ON fisica.umestrut
		  USING btree
		  (umestusuar, umeorigem, umestpesof, umestnivel);
		
		-- Index: iumestr5
		
		-- DROP INDEX iumestr5;

		CREATE INDEX iumestr5
		  ON fisica.umestrut
		  USING btree
		  (umestusuar, umevlrnive, umestnivel);
    END IF;        

END 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_schema_fisica()
  OWNER TO postgres;
