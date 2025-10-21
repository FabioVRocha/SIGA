--- Function: fn_Chk_Nulos_Produtos()

-- DROP FUNCTION fn_Chk_Nulos_Produtos();

CREATE OR REPLACE FUNCTION fn_Chk_Nulos_Produtos()
  RETURNS void AS
$BODY$
DECLARE
 
BEGIN
	
UPDATE produto
SET   procveng = COALESCE(procveng, 0.0),
      probrcom = COALESCE(probrcom, 0.0),
      probrlar = COALESCE(probrlar, 0.0),
     probresp = COALESCE(probresp, 0.0)
where procveng ISNULL
OR    probrcom ISNULL
OR    probrlar ISNULL
OR    probresp ISNULL;

ALTER TABLE produto ALTER COLUMN procveng SET DEFAULT 0;
ALTER TABLE produto ALTER COLUMN probrcom SET DEFAULT 0;
ALTER TABLE produto ALTER COLUMN probrlar SET DEFAULT 0;
ALTER TABLE produto ALTER COLUMN probresp SET DEFAULT 0;

END;
$BODY$
  LANGUAGE plpgsql VOLATILE COST 100;
  
ALTER FUNCTION fn_Chk_Nulos_Produtos()
  OWNER TO postgres;
