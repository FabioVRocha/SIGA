-- Function: fn_planilhamento_pf()

-- DROP FUNCTION fn_planilhamento_pf();

CREATE OR REPLACE FUNCTION fn_planilhamento_pf()
  RETURNS trigger AS
$BODY$
DECLARE
   vfase integer;
   voperacao char(5);
   vmaquina char(5);
   vproduto char(16);
   vhoras numeric(11,6);
   vhoraAtual char(8);
   vcount integer;
   vminutosProc numeric(12,4);
   vminutosReserv numeric(12,4);
   vsomaminutos numeric(12,4); 
   vreserva numeric(11,6);
   vresto numeric(11,6);
   vinteiro numeric(11,6);
BEGIN
   IF (SELECT rdcolpf FROM notparam WHERE notparam = 1) = 'K' THEN
		
	   IF (TG_OP = 'UPDATE') THEN

	        vproduto = (SELECT ord.ordproduto FROM ordem ord WHERE ord.ordem = NEW.ordem::integer);
	        vfase = (SELECT pr.fase FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);
	        voperacao = (SELECT pr.prccodig FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);	
	        vmaquina = (SELECT pr.maquina FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);	
	        vhoras = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, NEW.data_hora_fim, 'S'));	

	        IF (OLD.processado = '1') AND (NEW.processado = '0') then
	        	--raise notice 'processado = 1';
			    IF (SELECT count(*)
					FROM planilha
					WHERE plaordem = NEW.ordem::integer
					AND pladata = NEW.data_hora_inicio::date
					AND plamaquina = vmaquina
					AND plafuncion = NEW.operador::integer
					AND plahrini = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'))) > 0 THEN

					vhoras = (SELECT plahoras
								FROM planilha
						  WHERE plaordem = NEW.ordem::integer
							AND pladata = NEW.data_hora_inicio::date
							AND plamaquina = vmaquina
							AND plafuncion = NEW.operador::integer
							AND plahrini = (select fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N')) LIMIT 1);

					vreserva = (SELECT rprtmpreq
							FROM respror
						WHERE rprfase = vfase
						  AND rproper = voperacao
						  AND rprmaq = vmaquina
						  AND rprproce = NEW.sequencia
						  AND rprordem = NEW.ordem::integer);
				
					UPDATE respror
					SET rprtmpreq = (SELECT fn_Calculo_Horas(rprtmpreq, vhoras, '-')),
						rprqtreq = rprqtreq - NEW.qtde_produzido
					WHERE rprfase = vfase
					  AND rproper = voperacao
					  AND rprmaq = vmaquina
					  AND rprproce = NEW.sequencia
					  AND rprordem = NEW.ordem::integer;

				

					DELETE FROM planilha WHERE plaordem = NEW.ordem::integer
							AND pladata = NEW.data_hora_inicio::date
							AND plamaquina = vmaquina
							AND plafuncion = NEW.operador::integer
							AND plahrini = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'));

					vhoraAtual = (SELECT current_time::char(8));
					
					vcount = (SELECT count(*) + 1
							FROM logaces
					  WHERE lgaorigem = 'GERAL'
						AND lgadata = current_date
						AND lgahora = vhoraAtual);
				
					IF (vcount > 0) THEN
						vcount = vcount + 1;
					END IF;

					INSERT INTO logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao)
						VALUES(
						'GERAL',
						(select current_date),
						vhoraAtual || vcount,
						'ColetorP&F',
						'Excluído planilhamento de produção para a ordem ' || NEW.ordem ||', no processo ' || NEW.sequencia ||' pela integração com coletores P&F.',
						(SELECT substring(dadversao,1,9) FROM dadosemp LIMIT 1));
				END IF;
				return new;
			ELSE     -- Já existe planilhamento incluído com hora final Zero
				--raise notice 'processado = 0';
				IF (OLD.processado = '0') then  -- AND (NEW.processado = '0') then
					--raise notice 'processado = 0 acessou';
					IF (SELECT count(*)
						FROM planilha
						WHERE plaordem = NEW.ordem::integer AND pladata = NEW.data_hora_inicio::date
						AND plamaquina = vmaquina AND plafuncion = NEW.operador::integer
						AND plahrini = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'))) > 0 THEN
						
						UPDATE planilha 
							SET  plahrfim = (SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N')), 
							plahoras = vhoras, 							
							plaquant = NEW.qtde_produzido
						WHERE plaordem = NEW.ordem::integer
							AND pladata = NEW.data_hora_inicio::date
							AND plamaquina = vmaquina
							AND plafuncion = NEW.operador::integer
							AND plahrini = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'));
				
						vreserva = (select rprtmpreq from respror
						WHERE rprfase = vfase
						  AND rproper = voperacao
						  AND rprmaq = vmaquina
						  AND rprproce = NEW.sequencia
						  AND rprordem = NEW.ordem::integer);
			
						IF (OLD.data_hora_fim = ('0001-01-01 00:00:00')::timestamp) AND (NEW.data_hora_fim <> ('0001-01-01 00:00:00')::timestamp) AND (NEW.processado = '0') THEN
							 UPDATE respror
							 SET
							  rprtmpreq = (select fn_Calculo_Horas(vhoras, vreserva, '+')),
							  rprqtreq  = rprqtreq + NEW.qtde_produzido
							WHERE rprfase = vfase
							  AND rproper = voperacao
							  AND rprmaq = vmaquina
							  AND rprproce = NEW.sequencia
							  AND rprordem = NEW.ordem::integer;
							
							UPDATE ordens_log
							SET processado = '1',
							  fase_passada = 'N'
							WHERE ordem = NEW.ordem
							and maquina = NEW.maquina and sequencia = NEW.sequencia and data_hora_inicio = NEW.data_hora_inicio;
						end if;
					
						vhoraAtual = (select current_time::char(8));
						
						vcount = (SELECT count(*)
							 FROM logaces
						  WHERE lgaorigem = 'GERAL'
							 AND lgadata = current_date
							 AND lgahora = vhoraAtual);
					
						IF (vcount > 0) THEN
							vcount = vcount + 1;
							vhoraAtual = vhoraAtual || vcount;
						END IF;

						--INSERT INTO logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao)
						--VALUES(
						--	'GERAL',
						--	(SELECT current_date),
						--	vhoraAtual,
					    --		'ColetorP&F',
						--	'Editado planilhamento de produção para a ordem ' || NEW.ordem ||', no processo ' || NEW.sequencia ||' pela integração com coletores P&F.',
						--	(SELECT substring(dadversao,1,9) FROM dadosemp LIMIT 1));
					END IF;
					return new;
				END IF;	
		    END IF;

	   ELSE  --  Insert   *******
	   
	   		vproduto = (SELECT ord.ordproduto FROM ordem ord WHERE ord.ordem = NEW.ordem::integer);
	        vfase = (SELECT pr.fase FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);
	        voperacao = (SELECT pr.prccodig FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);	
	        vmaquina = (SELECT pr.maquina FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);	
	        vhoras = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, NEW.data_hora_fim, 'S'));	
		
			IF (NEW.data_hora_fim <> ('0001-01-01 00:00:00')::timestamp) AND (NEW.processado = '0') THEN
	
			   INSERT INTO planilha (plaordem, pladata, plamaquina, plafuncion, plahrini, plahrfim, plahoras, plaopera, plaquant, plafase, plaprod, plaproc, plareserv)
				   VALUES(
					NEW.ordem::integer,
					current_date,
					vmaquina,
					NEW.operador::integer,
					(SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N')),
					(SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N')),
					vhoras,
					voperacao,
					NEW.qtde_produzido,
					vfase,
					vproduto,
					NEW.sequencia,
					(SELECT rprnumero FROM respror WHERE rprfase = vfase AND rproper = voperacao AND rprmaq = vmaquina AND rprproce = NEW.sequencia AND rprordem = NEW.ordem::integer));
					
				    vreserva = (select rprtmpreq
						 from respror
					WHERE rprfase = vfase
					  AND rproper = voperacao
					  AND rprmaq = vmaquina
					  AND rprproce = NEW.sequencia
					  AND rprordem = NEW.ordem::integer);

			
				    UPDATE respror
					SET
					  rprtmpreq = (select fn_Calculo_Horas(vhoras, vreserva, '+')),
					  rprqtreq  = rprqtreq + NEW.qtde_produzido
					WHERE rprfase = vfase
					  AND rproper = voperacao
					  AND rprmaq = vmaquina
					  AND rprproce = NEW.sequencia
					  AND rprordem = NEW.ordem::integer;
					
				    UPDATE ordens_log
				    SET processado = '1',
                      fase_passada = 'N'
				    WHERE ordem = NEW.ordem
				    and maquina = NEW.maquina and sequencia = NEW.sequencia and data_hora_inicio = NEW.data_hora_inicio;

				    vhoraAtual = (select current_time::char(8));
					
				    vcount = (SELECT count(*)
						 FROM logaces
					  WHERE lgaorigem = 'GERAL'
						 AND lgadata = current_date
						 AND lgahora = vhoraAtual);
				
				    IF (vcount > 0) THEN
					    vcount = vcount + 1;
					    vhoraAtual = vhoraAtual || vcount;
				    END IF;

				    INSERT INTO logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao)
					VALUES(
						'GERAL',
						(SELECT current_date),
						vhoraAtual,
						'ColetorP&F',
						'Incluído planilhamento de produção para a ordem ' || NEW.ordem ||', no processo ' || NEW.sequencia ||' pela integração com coletores P&F.',
						(SELECT substring(dadversao,1,9) FROM dadosemp LIMIT 1));
			
			ELSE  -- Hora final não preenchida
				vhoras = 0;
				IF (NEW.data_hora_fim = ('0001-01-01 00:00:00')::timestamp) AND (NEW.processado = '0') and (SELECT rdcolin FROM pareqd2 WHERE pareqcod = 1) = 'S' THEN
				 --AND (SELECT rdcolin FROM notparam WHERE notparam = 1) = 'S' THEN
	
				   INSERT INTO planilha (plaordem, pladata, plamaquina, plafuncion, plahrini, plahrfim, plahoras, plaopera, plaquant, plafase, plaprod, plaproc, plareserv)
					   VALUES(
						NEW.ordem::integer,
						current_date,
						vmaquina,
						NEW.operador::integer,
						(SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N')),
						(SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N')),
						vhoras,
						voperacao,
						NEW.qtde_produzido,
						vfase,
						vproduto,
						NEW.sequencia,
						(SELECT rprnumero FROM respror WHERE rprfase = vfase AND rproper = voperacao AND rprmaq =
						vmaquina AND rprproce = NEW.sequencia AND rprordem = NEW.ordem::integer));
						
						
				--		UPDATE ordens_log
				--		SET processado = '0',
				--		fase_passada = 'N'
				--		WHERE ordem = NEW.ordem
				--		and maquina = NEW.maquina and sequencia = NEW.sequencia and data_hora_inicio = NEW.data_hora_inicio;						
						
						vhoraAtual = (select current_time::char(8));
					
						vcount = (SELECT count(*)
						FROM logaces
						WHERE lgaorigem = 'GERAL'
						AND lgadata = current_date
						AND lgahora = vhoraAtual);
				
						IF (vcount > 0) THEN
							vcount = vcount + 1;
							vhoraAtual = vhoraAtual || vcount;
						END IF;

						INSERT INTO logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao)
						VALUES(
						'GERAL',
						(SELECT current_date),
						vhoraAtual,
						'ColetorP&F',
						'Incluído planilhamento de produção para a ordem ' || NEW.ordem ||', no processo ' || NEW.sequencia ||' pela integração com coletores P&F.',
						(SELECT substring(dadversao,1,9) FROM dadosemp LIMIT 1));
						
				END IF;
		   		return new;
		   		
		   END IF;
	
	       RETURN NEW;
	
	    END IF;	
	   
		return new;
    END IF;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_planilhamento_pf() SET search_path=public, pg_temp;

ALTER FUNCTION fn_planilhamento_pf()
  OWNER TO postgres;