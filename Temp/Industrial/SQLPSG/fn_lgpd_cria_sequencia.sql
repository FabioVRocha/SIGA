-- Function: fn_lgpd_cria_sequencia(character, character)

-- DROP FUNCTION fn_lgpd_cria_sequencia(character, character);

CREATE OR REPLACE FUNCTION fn_lgpd_cria_sequencia(p_usuario character, p_versao character)
  RETURNS text AS
$BODY$
declare
	log_texto text;
	log_texto_full text;
	max_prlseq bigint;
	current_prlseq bigint;	
begin
	-- Cria sequencia dos logs da LGPD no banco caso ainda nao exista
	if (coalesce((select 1 from pg_class where relkind = 'S' and relname = 'seq_lgpd_logs'), 0) <> 1) then
		CREATE SEQUENCE seq_lgpd_logs;
	end if;

	log_texto_full := '';
	/* verifica se o maior (max) valor na tabela é maior que o atual (current) da sequência
	Se for, deve atualizar a sequencia e gravar log */
	
	/*PESRLOG SEQUENCIA*/
	select max(prlseq) from PESRLOG into max_prlseq;
	select last_value from seq_lgpd_logs into current_prlseq;
	
	if (max_prlseq > current_prlseq) then 
		log_texto := 'Sequência seq_lgpd_logs atualizada de ' || current_prlseq || ' para ' || max_prlseq || '.';
		log_texto_full := log_texto_full || log_texto;
		Insert into logaces(lgaorigem,lgadata,lgahora,lgausuar,lgatexto,lgaversao) values ('LGPDSeq', now(), to_char(now(), 'HH24:MI:SS'), p_usuario, 'LGPD|fn_lgpd_cria_sequencia: ' || log_texto, p_versao);
		perform setval('seq_lgpd_logs', max_prlseq);
	end if;	
	
	if(length(log_texto_full) > 0) then
		log_texto_full := substring(log_texto_full, 1, length(log_texto_full) - 1 );
	end if;
	
	return log_texto_full;
end; $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_lgpd_cria_sequencia(character, character)
  OWNER TO postgres;
