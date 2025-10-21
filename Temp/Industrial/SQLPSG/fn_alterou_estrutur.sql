-- Function: fn_alterou_estrutur()

-- DROP FUNCTION fn_alterou_estrutur();

CREATE OR REPLACE FUNCTION fn_alterou_estrutur()
  RETURNS trigger AS
$BODY$
declare
	v_data date;
	v_horario varchar; 
	v_ip varchar;
	--v_app varchar;
	--v_query varchar;
	v_usuario varchar;
BEGIN
/*
	Tabela ESTRUTUR
	Campos
	ESTUSUALT caractere 10,
	ESTDTALT date,
	ESTHRALT caractere 8,
	ESTUSUHASH caractere 10,
	ESTDTHASH date,
	ESTHRHASH caractere 8,
*/
	
	if TG_OP <> 'DELETE' then		
		v_data = (select current_date);
		v_horario = (select substring(current_time::text, 1, 8)); 

		v_usuario = fn_get_session_var('industrial.usuario');

		--Se o usuario nao estiver definido na sessao, pega o final do IP.
		if v_usuario is null then
			v_ip = (select inet_client_addr()::varchar);
			v_usuario = substring(v_ip, length(v_ip)- 9);
		end if;
		--v_app = (select application_name from pg_stat_activity where pid = pg_backend_pid());
		--v_query = (select current_query());
		
		--Atualiza o horario se algum atributo relevante ao hash foi alterado
/*
		if TG_OP = 'INSERT' OR NEW.estproduto <> OLD.estproduto 
			OR (NEW.estproduto is null and OLD.estproduto is not null)
			OR (NEW.estproduto is not null and OLD.estproduto is null)
			OR NEW.estfilho <> OLD.estfilho
			OR (NEW.estfilho is null and OLD.estfilho is not null)
			OR (NEW.estfilho is not null and OLD.estfilho is null)
			OR NEW.fase <> OLD.fase
			OR (NEW.fase is null and OLD.fase is not null)
			OR (NEW.fase is not null and OLD.fase is null)
			OR NEW.estusamed <> OLD.estusamed
			OR (NEW.estusamed is null and OLD.estusamed is not null)
			OR (NEW.estusamed is not null and OLD.estusamed is null)
			OR NEW.estarea <> OLD.estarea
			OR (NEW.estarea is null and OLD.estarea is not null)
			OR (NEW.estarea is not null and OLD.estarea is null)
			OR NEW.estqtduso <> OLD.estqtduso
			OR (NEW.estqtduso is null and OLD.estqtduso is not null)
			OR (NEW.estqtduso is not null and OLD.estqtduso is null)
			OR NEW.estpriemb <> OLD.estpriemb
			OR (NEW.estpriemb is null and OLD.estpriemb is not null)
			OR (NEW.estpriemb is not null and OLD.estpriemb is null)
			OR NEW.estinfadi <> OLD.estinfadi
			OR (NEW.estinfadi is null and OLD.estinfadi is not null)
			OR (NEW.estinfadi is not null and OLD.estinfadi is null) THEN
*/
			NEW.ESTDTALT = v_data;
			NEW.ESTHRALT = v_horario;
			NEW.ESTUSUALT = v_usuario;
		--end if;
		
		--O hash e horario deve ser gravado pela funcao que gerou ele.
		--Se o hash mudou, alimenta o usuario e horario de alteracao do hash
		if TG_OP = 'UPDATE' AND NEW.ESTHASH <> OLD.ESTHASH then
		--	NEW.ESTDTHASH = v_data;
		--	NEW.ESTHRHASH = v_horario;
			NEW.ESTUSUHASH = v_usuario;
		end if;
		

		--Se o hash esta em branco ou nulo limpa hash e o horario de geracao
		if nullif(trim(NEW.ESTHASH), '') is null then
			NEW.ESTHASH = '';
			NEW.ESTDTHASH = '0001-01-01';
			NEW.ESTHRHASH = '00:00';
			NEW.ESTUSUHASH = v_usuario;
		end if;
	end if;

	if TG_OP = 'DELETE' then
		RETURN OLD;
	else
		RETURN NEW;
	end if;
		
	
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_alterou_estrutur()
  OWNER TO postgres;
