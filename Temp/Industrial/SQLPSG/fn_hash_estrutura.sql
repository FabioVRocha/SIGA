-- Function: fn_hash_estrutura(character, character, character, character, character)

-- DROP FUNCTION fn_hash_estrutura(character, character, character, character, character);

CREATE OR REPLACE FUNCTION fn_hash_estrutura(pproduto character, pengestver character, pgravahash character, pnivelzero character, pconfatmed character)
  RETURNS text AS
$BODY$
DECLARE
	vhash text;
BEGIN
	
	vhash = fn_gerar_hash(pproduto, pengestver, pgravahash, ''/*nao utilizado*/, 'N', pconfatmed, ''/*nao utilizado*/,''/*nao utilizado*/);

	if pgravahash = 'S' and pengestver = 'S' then
		update verestru
			set vereshash = vhash
		where veresvpa = (select estver from estrutur where estproduto = pproduto limit 1)
		and verespai = pproduto
		and pengestver = 'S';
	end if;

	return vhash;
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE --SECURITY DEFINER
  COST 100;
ALTER FUNCTION fn_hash_estrutura(character, character, character, character, character)
  OWNER TO postgres;
