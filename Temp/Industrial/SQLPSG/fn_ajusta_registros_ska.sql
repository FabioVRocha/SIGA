-- Function: fn_ajusta_registros_ska()

-- DROP FUNCTION fn_ajusta_registros_ska();

CREATE OR REPLACE FUNCTION fn_ajusta_registros_ska()
  RETURNS void AS
$BODY$
	
declare
   v_registros planilha%ROWTYPE;
   v_plaordem numeric;
   v_pladata date;
   v_plamaquina text;
   v_plafunciona numeric;
   v_plahrini numeric(5,2);
   v_datatime timestamp;
   v_plahrfim numeric(5,2);
   v_temregistro numeric;
   v_ord ordens_log%ROWTYPE;
begin	
	
	for v_registros in (select * from planilha p where p.plahoras is null and p.plahrini is not null) loop
		v_plaordem = v_registros.plaordem;
	    v_pladata = v_registros.pladata;
	    v_plamaquina = v_registros.plamaquina;
	    v_plafunciona = v_registros.plafuncion;
	    v_plahrini = v_registros.plahrini;
 	    v_plahrfim = v_registros.plahrfim;
	   
	    v_datatime = (v_pladata || ' ' || substring(lpad(v_plahrfim::text,5,'0'),1,2) || ':' || substring(lpad(v_plahrfim::text,5,'0'),4,2) )::timestamp;
	   
	    v_temregistro = (select count(*) from ordens_log ol where ol.ordem::numeric = v_plaordem and ol.data_hora_fim = v_datatime and ol.maquina = trim(v_plamaquina) and ol.operador::numeric = v_plafunciona limit 1);
	    --raise notice 'v_plaordem: %, v_datatime: %, v_plamaquina: %, v_plafunciona: %, v_temregistro: % ', v_plaordem, v_datatime, trim(v_plamaquina), v_plafunciona, v_temregistro;
	    if v_temregistro > 0 then --Caso encontre algum registro
	    	delete from planilha p where p.plaordem = v_plaordem and p.pladata = v_pladata and p.plamaquina = trim(v_plamaquina) and p.plafuncion = v_plafunciona and p.plahrini = v_plahrini;
	    	
	    	v_temregistro = (select count(*) from planilha p where p.plaordem = v_plaordem and p.pladata = v_pladata and p.plamaquina = trim(v_plamaquina) and p.plafuncion = v_plafunciona and p.plahrini = v_plahrini limit 1);
			--raise notice 'v_temregistro: %', v_temregistro;
	    
	    	SELECT * INTO v_ord
	        FROM ordens_log
	        WHERE ordem::numeric = v_plaordem
	          AND data_hora_fim = v_datatime
	          AND maquina = trim(v_plamaquina)
	          AND operador::numeric = v_plafunciona
	        LIMIT 1;
		
			DELETE FROM ordens_log
			WHERE ordem::numeric = v_plaordem
			  AND data_hora_fim = v_datatime
			  AND maquina = trim(v_plamaquina)
			  AND operador::numeric = v_plafunciona;
			
			INSERT INTO ordens_log (
	            maquina,
	            ordem,
	            descricao_ordem,
	            sequencia,
	            descricao_sequencia,
	            operador,
	            data_hora_inicio,
	            data_hora_fim,
	            qtde_produzido,
	            qtde_refugo,
	            processado,
	            tempo_operacao,
	            tempo_setup,
	            fase_passada,
	            motivoperda
	        ) VALUES (
	            v_ord.maquina,
	            v_ord.ordem,
	            v_ord.descricao_ordem,
	            v_ord.sequencia,
	            v_ord.descricao_sequencia,
	            v_ord.operador,
	            v_ord.data_hora_inicio,
	            v_ord.data_hora_fim,
	            v_ord.qtde_produzido,
	            v_ord.qtde_refugo,
	            0,  -- sobrescrevendo processado
	            v_ord.tempo_operacao,
	            v_ord.tempo_setup,
	            v_ord.fase_passada,
	            v_ord.motivoperda
	        );
	
	    end if;
	end loop
	;
	
end

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_ajusta_registros_ska()
  OWNER TO postgres;
