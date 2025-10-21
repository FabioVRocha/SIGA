-- Function: fn_cad_update_sequences(character, character)

-- DROP FUNCTION fn_cad_update_sequences(character, character);

CREATE OR REPLACE FUNCTION fn_cad_update_sequences(p_usuario character, p_versao character)
  RETURNS text AS
$BODY$
declare
	log_texto text;
	log_texto_full text;
	max_cadlseq bigint;
	max_cadcont bigint;
	max_cadidlote bigint;
	current_cadlseq bigint;
	current_cadcont bigint;
	current_cadidlote bigint;
begin
	log_texto_full := '';
	/* verifica se o maior (max) valor na tabela é maior que o atual (current) da sequência
	Se for, deve atualizar a sequencia e gravar log */
	
	/*CADLOGS SEQUENCIA*/
	select max(cadlseq) from CADLOGS into max_cadlseq;
	select last_value from seq_cad_logs into current_cadlseq;
	
	if (max_cadlseq > current_cadlseq) then 
		log_texto := 'Sequência seq_cad_logs atualizada de ' || current_cadlseq || ' para ' || max_cadlseq || '.';
		log_texto_full := log_texto_full || log_texto || '\n';
		Insert into logaces(lgaorigem,lgadata,lgahora,lgausuar,lgatexto,lgaversao) values ('CadSeqU01', now(), to_char(now(), 'HH24:MI:SS'), p_usuario, 'IntegraCAD|fn_cad_update_sequences: ' || log_texto, p_versao);
		perform setval('seq_cad_logs', max_cadlseq);
	end if;
	
	/*CADIRETA CONTROLE*/
	select max(cadcont) from CADIRETA into max_cadcont;
	select last_value from seq_cad_controle into current_cadcont;
	
	if (max_cadcont > current_cadcont) then 
		log_texto := 'Sequência seq_cad_controle atualizada de ' || current_cadcont || ' para ' || max_cadcont || '.';
		log_texto_full := log_texto_full || log_texto || '\n';
		Insert into logaces(lgaorigem,lgadata,lgahora,lgausuar,lgatexto,lgaversao) values ('CadSeqU02', now(), to_char(now(), 'HH24:MI:SS'), p_usuario, 'IntegraCAD|fn_cad_update_sequences: ' || log_texto, p_versao);
		perform setval('seq_cad_controle', max_cadcont);
	end if;
	
	/*CADIRETA LOTE*/
	select max(cadidlote) from CADIRETA into max_cadidlote;
	select last_value from seq_cad_lote into current_cadidlote;
	
	if (max_cadidlote > current_cadidlote) then 
		log_texto := 'Sequência seq_cad_lote atualizada de ' || current_cadidlote || ' para ' || max_cadidlote || '.';
		log_texto_full := log_texto_full || log_texto || '\n';
		Insert into logaces(lgaorigem,lgadata,lgahora,lgausuar,lgatexto,lgaversao) values ('CadSeqU03', now(), to_char(now(), 'HH24:MI:SS'), p_usuario, 'IntegraCAD|fn_cad_update_sequences: ' || log_texto, p_versao);
		perform setval('seq_cad_lote', max_cadidlote);
	end if;	
	
	if(length(log_texto_full) > 0) then
		log_texto_full := substring(log_texto_full, 1, length(log_texto_full) - 1 );
	end if;
	
	return log_texto_full;
end; $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_cad_update_sequences(character, character)
  OWNER TO postgres;
