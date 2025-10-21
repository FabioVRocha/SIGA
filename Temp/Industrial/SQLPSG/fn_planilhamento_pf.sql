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
   vhoraini numeric(11,6);
   vhrinisetup numeric(11,6);
   vhrsetup numeric(11,6);
   vdatainicio date;  -- Os 4172124
   vdatafim date;
   vhorafinal numeric(11,6);
   vhorainicial numeric(11,6);
   vquantidade numeric(11,6);
   vdatahorainicial timestamp;
   vdatahorafinal timestamp;
   nn numeric(5);
   --OS 4297425
   dia_semana numeric;
   v_horft1f numeric(11,6);
   v_horft2f numeric(11,6);
   v_horft3f numeric(11,6);
   v_horft4f numeric(11,6);
   v_horft1i numeric(11,6);
   v_horft2i numeric(11,6);
   v_horft3i numeric(11,6);
   v_horft4i numeric(11,6);
   vhoras_min numeric(12,4);
   vtotal_horas numeric(11,6);
   vtotal_min numeric(11,6);
   vtempo_setup numeric(11,6);
   vtempo_operacao numeric(11,6);
   v_contaregistros numeric;
   v_conta numeric;
   v_plahora_min numeric(11,6);
   v_percen numeric(11,6);
   v_percen_total numeric(11,6);
   v_nova_data date;
   v_turnoentrou numeric;
   v_temturno numeric;
   ------
BEGIN
   IF (SELECT rdcolpf FROM notparam WHERE notparam = 1) = 'K' then
       vtotal_min = 0; --OS 4297425
	   IF (TG_OP = 'UPDATE') THEN

	        vproduto = (SELECT ord.ordproduto FROM ordem ord WHERE ord.ordem = NEW.ordem::integer);
	        vfase = (SELECT pr.fase FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);
	        voperacao = (SELECT pr.prccodig FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);	
		if (select count(*) from maquina m where m.maquina = new.maquina) > 0 then
			vmaquina = new.maquina;
		else
			vmaquina = (SELECT pr.maquina FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);
		end if;
	        vhoras = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, NEW.data_hora_fim, 'S'));	
		vhoraini = (SELECT fn_Converte_Hora('0001-01-01 00:00:00', NEW.data_hora_inicio, 'S'));
		if (SELECT rdsetpla FROM pareqd2 WHERE pareqcod = 1) = 'S' then
			vhrsetup = (select fn_tranforma_horas_decimal(NEW.tempo_setup));
			--vhrinisetup = (select fn_Calculo_Horas(vhoraini, vhrsetup , '-'));
			vdatainicio = NEW.data_hora_inicio::date;
		    vhrinisetup = (select fn_ska_calculo_Horas(vhoraini, vhrsetup, '-' , vhrinisetup, vdatainicio)); -- OS 4172124			
			vdatainicio = (select fn_ska_calculo_Horas1(vhoraini, vhrsetup , '-', vhrinisetup, vdatainicio)); -- OS 4172124

			vhoras = (select fn_Calculo_Horas(vhoras, vhrsetup , '+'));
		else
			vdatainicio = NEW.data_hora_inicio::date;
			vhrinisetup = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'));
		end if ;					
	        IF (OLD.processado = '1') AND (NEW.processado = '0') then
			    IF (SELECT count(*)
					FROM planilha
					WHERE plaordem = NEW.ordem::integer
					AND pladata = vdatainicio   --NEW.data_hora_inicio::date  Os 4172124
					AND plamaquina = vmaquina
					AND plafuncion = NEW.operador::integer
					AND plahrini = vhrinisetup ) > 0 THEN
					--AND plahrini = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'))) > 0 THEN

					vhoras = (SELECT plahoras
								FROM planilha
						  WHERE plaordem = NEW.ordem::integer
							AND pladata = vdatainicio -- NEW.data_hora_inicio::date OS 4172124
							AND plamaquina = vmaquina
							AND plafuncion = NEW.operador::integer
							AND plahrini = vhrinisetup LIMIT 1); --(select fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N')) LIMIT 1);

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
							AND pladata = vdatainicio -- NEW.data_hora_inicio::date OS 4172124
							AND plamaquina = vmaquina
							AND plafuncion = NEW.operador::integer
							AND plahrini = vhrinisetup; --(SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'));

					vhoraAtual = '';
					vhoraAtual = (select clock_timestamp()::time::char(8));
				    vcount = 0;
				    vcount = coalesce((SELECT 1
						 FROM logaces
					  WHERE lgaorigem = 'GERAL'
						 AND lgadata = current_date
						 AND lgahora = vhoraAtual),0);
				
					IF (vcount > 0) then
						--vcount = vcount + 1;
						--vhoraAtual = (SELECT current_time::time::char(5));
						loop
							if (vcount > 940) then
					    		PERFORM pg_sleep(1);
					    	end if;
							vcount = vcount + 1;
							vhoraAtual = (select clock_timestamp()::time::char(5)) || vcount;
							if (SELECT count(*)
								FROM logaces
								WHERE lgaorigem = 'GERAL'
								AND lgadata = current_date
								AND lgahora = vhoraAtual) = 0 then
									exit;
							end if;
						end loop;
					END IF;

					INSERT INTO logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao)
						VALUES(
						'GERAL',
						(select current_date),
						vhoraAtual, --|| vcount,
						'ColetorP&F',
						'Excluido planilhamento de producao para a ordem ' || NEW.ordem ||', no processo ' || NEW.sequencia ||' pela integracao com coletores P&F.',
						(SELECT substring(dadversao,1,9) FROM dadosemp LIMIT 1));
				END IF;
				return new;
			ELSE     -- Ja existe planilhamento incluido com hora final Zero
				vhrinisetup = ROUND(vhrinisetup,2);
				IF (OLD.processado = '0') AND (OLD.data_hora_fim = ('0001-01-01 00:00:00')::timestamp) AND (NEW.data_hora_fim <> ('0001-01-01 00:00:00')::timestamp) then  -- AND (NEW.processado = '0') then
					IF (SELECT count(*)
						FROM planilha
						WHERE plaordem = NEW.ordem::integer AND pladata = vdatainicio --NEW.data_hora_inicio::date
						AND plamaquina = vmaquina AND plafuncion = NEW.operador::integer
						AND plahrini = vhrinisetup ) > 0 THEN --(SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'))) > 0 then
						
						vdatafim = new.data_hora_fim::date; -- OS 4172124
						if vdatainicio = vdatafim then
							vhorafinal = (select fn_converte_hora(new.data_hora_fim,('0001-01-01 00:00:00')::timestamp,'N'));
							vquantidade = new.qtde_produzido;
						
							--OS 4297425
							SELECT EXTRACT(DOW FROM vdatainicio) into dia_semana + 1; --Soma 1 pois o "horfdia" inicia o domingo com o valor 1, e o sql retorna o domingo com valor 0.
							
							select horft1i, horft1f, horft2i, horft2f, horft3i, horft3f, horft4i, horft4f into v_horft1i, v_horft1f, v_horft2i, v_horft2f, v_horft3i, v_horft3f, v_horft4i, v_horft4f 
								from horfunc h where h.horfunc = new.operador::integer and h.horfdia = dia_semana;
							
							if v_horft1f > 0 then
								--if (vhrinisetup >= v_horft1i and vhorafinal <= v_horft1f) or (vhrinisetup >= v_horft2i and vhorafinal <= v_horft2f) or (vhrinisetup >= v_horft3i and vhorafinal <= v_horft3f)
								if (vhorafinal <= v_horft1f) or (vhrinisetup >= v_horft2i and vhorafinal <= v_horft2f) or (vhrinisetup >= v_horft3i and vhorafinal <= v_horft3f)
									or (vhrinisetup >= v_horft4i) then
									--or (vhrinisetup >= v_horft4i and vhorafinal <= v_horft4f) then
										vhoras_min = (select fn_transforma_horas_em_minutos(new.tempo_operacao)) + (select fn_transforma_horas_em_minutos(new.tempo_setup)); --Soma tempo de operacao e setup
										vhoras_min = (vhoras_min / 60);
										vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 );
								
								else
									--Hora inicial
									--if (vhrinisetup >= v_horft1i and vhrinisetup <= v_horft1f) then
									if (vhrinisetup <= v_horft1f) then
										vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
										v_turnoentrou = 1;
									end if;
								
									--if (vhrinisetup >= v_horft2i and vhrinisetup <= v_horft2f) then
									if (vhrinisetup <= v_horft2f) then
										vhoras_min = (select fn_transforma_horas_em_minutos(v_horft2f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
										v_turnoentrou = 2;
									end if;
								
									--if (vhrinisetup >= v_horft3i and vhrinisetup <= v_horft3f) then
									if (vhrinisetup <= v_horft3f) then
										vhoras_min = (select fn_transforma_horas_em_minutos(v_horft3f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
										v_turnoentrou = 3;
									end if;
								
									if (vhrinisetup >= v_horft4i) then
										vhoras_min = (select fn_transforma_horas_em_minutos(v_horft4f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
										v_turnoentrou = 4;
									end if;
								
									--Hora final
									if (vhorafinal >= v_horft2i and vhorafinal <= v_horft2f) then
									 		vhoras_min = vhoras_min + ((select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft2i)) );
									end if;
									if (vhorafinal >= v_horft3i and vhorafinal <= v_horft3f) then
										if v_turnoentrou = 1 then
									 	     vhoras_min = vhoras_min + (select fn_transforma_horas_em_minutos(v_horft2f) - (select fn_transforma_horas_em_minutos(v_horft2i)) + 
									 		 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft3i)) );
								 		else
								 			vhoras_min = vhoras_min + ( (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft3i)) );
								 		end if;
									end if;
									--if (vhorafinal >= v_horft4i and vhorafinal <= v_horft4f) then
									if (vhorafinal >= v_horft4i) then
										if v_turnoentrou = 1 then
											vhoras_min = vhoras_min + (select fn_transforma_horas_em_minutos(v_horft2f) - (select fn_transforma_horas_em_minutos(v_horft2i)) + 
														 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
														 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
										else
											if v_turnoentrou = 2 then
												vhoras_min = vhoras_min + ( (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
														 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
											else
												vhoras_min = vhoras_min + ( (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
											end if;
										end if;
									end if;
									--end if;
									vtotal_min = vhoras_min;
									vtempo_operacao = (select fn_transforma_horas_em_minutos(new.tempo_operacao));
									vtempo_setup    = (select fn_transforma_horas_em_minutos(new.tempo_setup));
									if vtotal_min > (vtempo_operacao + vtempo_setup) then
										vtotal_min = vhoras_min - (vtotal_min - (vtempo_operacao + vtempo_setup));
										vtotal_min = (vtotal_min / 60);
										vhoras = trunc(vtotal_min) + (( (vtotal_min - trunc(vtotal_min)) * 60) / 100 ); --Transforma minutos em horas
									else
										vhoras_min = (vhoras_min / 60);
										vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 );
									end if;
								end if;
							end if;
						else
							--OS 4297425
							SELECT EXTRACT(DOW FROM vdatainicio) into dia_semana + 1; --Soma 1 pois o "horfdia" inicia o domingo com o valor 1, e o sql retorna o domingo com valor 0.
							
							select horft1i, horft1f, horft2i, horft2f, horft3i, horft3f, horft4i, horft4f into v_horft1i, v_horft1f, v_horft2i, v_horft2f, v_horft3i, v_horft3f, v_horft4i, v_horft4f 
								from horfunc h where h.horfunc = new.operador::integer and h.horfdia = dia_semana;
							
							if v_horft1f > 0 then
								if vdatainicio <> vdatafim then
									if v_horft4f > 0 then
										vhorafinal = v_horft4f;
									else
										if v_horft3f > 0 then
											vhorafinal = v_horft3f;
										else
											if v_horft2f > 0 then
												vhorafinal = v_horft2f;
											else
												vhorafinal = v_horft1f;
											end if;
										end if;
									end if;
									vquantidade = 0;
								end if;
								--if (vhrinisetup >= v_horft1i and vhrinisetup <= v_horft1f) then
								if (vhrinisetup <= v_horft1f) then
									vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) + 
										 	 (select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(v_horft2i)) +
										 	 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
											 (select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
								else
									if (vhrinisetup >= v_horft2i and vhrinisetup <= v_horft2f) then
										vhoras_min = ((select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(vhrinisetup)) +
											 	 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
												 (select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
						 		 	else
						 		 		if (vhrinisetup >= v_horft3i and vhrinisetup <= v_horft3f) then
						 		 			vhoras_min = ((select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(vhrinisetup)) +
													 (select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
										else
											vhoras_min = ((select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
						 		 		end if;
									end if;
								end if;
										
								vtotal_min = vtotal_min + vhoras_min;
								vhoras_min = (vhoras_min / 60);
								vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 ); --Transforma minutos em horas
							else
							-------
								vhorafinal = 23.59;
								vquantidade = 0;
								--vhoras = ((trunc(vhorafinal ) * 60 + ( (vhorafinal - trunc(vhorafinal )) * 100 )) - (trunc(vhrinisetup ) * 60 + ( (vhrinisetup - trunc(vhrinisetup )) * 100 ))) / 100;
								vhoras = vhorafinal - vhrinisetup;
							end if;
						end if;
										
						UPDATE planilha 
							SET  plahrfim =  vhorafinal, --(SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N')),   Os 4172124 
							plahoras = vhoras, 							
							plaquant = vquantidade -- NEW.qtde_produzido OS 4172124
						WHERE plaordem = NEW.ordem::integer
							AND pladata = vdatainicio  --NEW.data_hora_inicio::date  Os 4172124
							AND plamaquina = vmaquina
							AND plafuncion = NEW.operador::integer
							AND plahrini = vhrinisetup;--(SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'));
						
							if vdatainicio <> vdatafim then   -- OS 4172124
								vdatainicio = vdatainicio + interval '1 day';
								v_contaregistros = 1;
								while  vdatainicio <= vdatafim loop
									--OS 4327225
									v_temturno = (select coalesce(1,0) from horfunc h where h.horfunc = new.operador::integer limit 1);
									if v_temturno <> 1 then --Para garantir que caso seja nullo alimenta com zero.
										v_temturno = 0;
									end if;
									--
									
									--OS 4297425
									SELECT EXTRACT(DOW FROM vdatainicio) into dia_semana + 1; --Soma 1 pois o "horfdia" inicia o domingo com o valor 1, e o sql retorna o domingo com valor 0.
									
									select horft1i, horft1f, horft2i, horft2f, horft3i, horft3f, horft4i, horft4f into v_horft1i, v_horft1f, v_horft2i, v_horft2f, v_horft3i, v_horft3f, v_horft4i, v_horft4f 
										from horfunc h where h.horfunc = new.operador::integer and h.horfdia = dia_semana;
									
									if v_horft1f > 0 then
										v_temturno = 2; --OS 4327225
										vhorainicial = v_horft1i;
										if vdatainicio <> vdatafim then
											if v_horft4f > 0 then
												vhorafinal = v_horft4f;
											else
												if v_horft3f > 0 then
													vhorafinal = v_horft3f;
												else
													if v_horft2f > 0 then
														vhorafinal = v_horft2f;
													else
														vhorafinal = v_horft1f;
													end if;
												end if;
											end if;
																				
											vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(v_horft1i)) + 
													     (select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(v_horft2i)) +
													     (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
													 	 (select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
										else
											vhorafinal = (SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N'));
											--if (vhorafinal >= v_horft1i and vhorafinal <= v_horft1f) then
											if (vhorafinal <= v_horft1f) then
												vhoras_min = (select fn_transforma_horas_em_minutos(vhorafinal) - (select fn_transforma_horas_em_minutos(v_horft1i)) );
											else
												if (vhorafinal >= v_horft2i and vhorafinal <= v_horft2f) then
													vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(v_horft1i)) + 
													 		 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft2i)) );
									 		 	else
									 		 		if (vhorafinal >= v_horft3i and vhorafinal <= v_horft3f) then
									 		 			vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(v_horft1i)) + 
																 (select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(v_horft2i)) +
																 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft3i)) );
													else
														vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(v_horft1i)) + 
																 (select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(v_horft2i)) +
																 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
																 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
									 		 		end if;
												end if;
											end if;
										end if;
										vtotal_min = vtotal_min + vhoras_min;
										
										if vdatainicio = vdatafim then
											vtempo_operacao = (select fn_transforma_horas_em_minutos(new.tempo_operacao));
											vtempo_setup    = (select fn_transforma_horas_em_minutos(new.tempo_setup));
											if vtotal_min > (vtempo_operacao + vtempo_setup) then
												v_percen_total = 100;
												v_contaregistros = v_contaregistros + 1;
												vtotal_min = (vtotal_min - (vtempo_operacao + vtempo_setup));
												--Faz o rateio da sobra do tempo total
												while 1 < v_contaregistros and v_percen_total <> 0 loop
													v_contaregistros = v_contaregistros - 1;
													v_plahora_min = 0;
													v_nova_data = vdatainicio - (v_contaregistros || 'day')::interval;
													v_plahora_min = fn_transforma_horas_em_minutos((select plahoras from planilha p where p.plaordem = NEW.ordem::integer and p.pladata = v_nova_data));
													
													if (v_plahora_min is not null) then	--4327225. Para desconsiderar os dias que o funcionario nao tem turno
														v_percen = ((v_plahora_min * 100) / vtotal_min);
														if v_percen > 10 then
															v_percen = v_percen - 10;
														end if;
														if v_percen > v_percen_total then
															v_percen = v_percen_total;
														end if;
														v_plahora_min = v_plahora_min - (vtotal_min * v_percen) / 100;
														v_percen_total = v_percen_total - v_percen;
													
														v_plahora_min = (v_plahora_min / 60);
														vhoras = trunc(v_plahora_min) + (( (v_plahora_min - trunc(v_plahora_min)) * 60) / 100 ); --Transforma minutos em horas
														update planilha set plahoras = vhoras where plaordem = NEW.ordem::integer and pladata = v_nova_data;
													end if;
												end loop;
												if v_percen_total > 0 then
													vtotal_min = vhoras_min - (vtotal_min * v_percen_total) / 100;
												else 
													vtotal_min = vhoras_min;
												end if;
												vtotal_min = (vtotal_min / 60);
												vhoras = trunc(vtotal_min) + (( (vtotal_min - trunc(vtotal_min)) * 60) / 100 ); --Transforma minutos em horas
											else
												vhoras_min = (vhoras_min / 60);
												vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 );
											end if;
										else
											v_contaregistros = v_contaregistros + 1;
											vhoras_min = (vhoras_min / 60);
											vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 ); --Transforma minutos em horas
										end if;
									else
									-------
										if (v_temturno = 0) then --OS 4327225. Somente se o funcionario nao tiver NENHUM dia da semana com turno.
											v_temturno = 2; --OS 4327225
											if vdatainicio <> vdatafim then
												vhorainicial = 00.00;
												vhorafinal = 23.59;
												vhoras = 23.59;
											else
												vhorainicial = 00.00;
												vhorafinal = (SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N'));
												vhoras = vhorafinal;
											end if;
										end if;
									end if;
								
									if (v_temturno = 2) then --OS 4327225. Caso tenha turno no dia processado OU caso nao tenha turno em nenhum dia da semana
										INSERT INTO planilha (plaordem, pladata, plamaquina, plafuncion, plahrini, plahrfim, plahoras, plaopera, plaquant, plafase, plaprod, plaproc, plareserv)
							   			VALUES(
										NEW.ordem::integer,
										vdatainicio, 
										vmaquina,
										NEW.operador::integer,
										vhorainicial,
										vhorafinal,
										vhoras,
										voperacao,
										case
										  when vdatainicio = vdatafim then	NEW.qtde_produzido
										  else 0
										end,  
										vfase,
										vproduto,
										NEW.sequencia,
										(SELECT rprnumero FROM respror WHERE rprfase = vfase AND rproper = voperacao AND rprmaq =
										vmaquina AND rprproce = NEW.sequencia AND rprordem = NEW.ordem::integer));						
									end if;
								
									vdatainicio = vdatainicio + interval '1 day';
								end loop;
							end if;
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
					
						vhoraAtual = (select current_time::time::char(8));
						
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
						--	'Editado planilhamento de producao para a ordem ' || NEW.ordem ||', no processo ' || NEW.sequencia ||' pela integracao com coletores P&F.',
						--	(SELECT substring(dadversao,1,9) FROM dadosemp LIMIT 1));
					END IF;
					return new;
				END IF;	
		    END IF;

	   ELSE  --  Insert   *******
	   		--raise notice '1 %', new.ordem::integer;
	   		--raise notice 'entrou no insert';
	   		vdatainicio = coalesce(NEW.data_hora_inicio::date, current_date);
	   		vproduto = (SELECT ord.ordproduto FROM ordem ord WHERE ord.ordem = NEW.ordem::integer);
	        vfase = (SELECT pr.fase FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);
	        voperacao = (SELECT pr.prccodig FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);	
		if (select count(*) from maquina m where m.maquina = new.maquina) > 0 then
			vmaquina = new.maquina;
		else
			vmaquina = (SELECT pr.maquina FROM processo pr WHERE pr.processo = NEW.sequencia AND pr.produto = vproduto);
		end if;
	    vhoras = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, NEW.data_hora_fim, 'S'));	
		vhoraini = (SELECT fn_Converte_Hora('0001-01-01 00:00:00', NEW.data_hora_inicio, 'S'));
		vdatafim = new.data_hora_fim::date; -- OS 4172124
		vhorafinal = (SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N')); -- OS 4172124
		vquantidade = new.qtde_produzido; -- OS 4172124
		if (SELECT rdsetpla FROM pareqd2 WHERE pareqcod = 1) = 'S' then
			vhrsetup = (select fn_tranforma_horas_decimal(NEW.tempo_setup));
			--vhrinisetup = (select fn_Calculo_Horas(vhoraini, vhrsetup , '-'));
			vhrinisetup = (select fn_ska_calculo_Horas(vhoraini, vhrsetup , '-', vhrinisetup, vdatainicio)); -- OS 4172124
			vdatainicio = (select fn_ska_calculo_Horas1(vhoraini, vhrsetup, '-', vhrinisetup, vdatainicio)); -- OS 4172124
			--raise notice 'No insert, acessou funcções %',vdatainicio;
			-- OS 4172124
			if vdatainicio <> vdatafim then
				--OS 4297425
				SELECT EXTRACT(DOW FROM vdatainicio) into dia_semana + 1; --Soma 1 pois o "horfdia" inicia o domingo com o valor 1, e o sql retorna o domingo com valor 0.
				
				select horft1i, horft1f, horft2i, horft2f, horft3i, horft3f, horft4i, horft4f into v_horft1i, v_horft1f, v_horft2i, v_horft2f, v_horft3i, v_horft3f, v_horft4i, v_horft4f 
					from horfunc h where h.horfunc = new.operador::integer and h.horfdia = dia_semana;
				
				if v_horft1f > 0 then
					if v_horft4f > 0 then
						vhorafinal = v_horft4f;
					else
						if v_horft3f > 0 then
							vhorafinal = v_horft3f;
						else
							if v_horft2f > 0 then
								vhorafinal = v_horft2f;
							else
								vhorafinal = v_horft1f;
							end if;
						end if;
					end if;
					vquantidade = 0;
					--if (vhrinisetup >= v_horft1i and vhrinisetup <= v_horft1f) then
					if (vhrinisetup <= v_horft1f) then
						vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) + 
							 	 (select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(v_horft2i)) +
							 	 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
								 (select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
					else
						if (vhrinisetup >= v_horft2i and vhrinisetup <= v_horft2f) then
							vhoras_min = ((select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(vhrinisetup)) +
								 	 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
									 (select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
			 		 	else
			 		 		if (vhrinisetup >= v_horft3i and vhrinisetup <= v_horft3f) then
			 		 			vhoras_min = ((select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(vhrinisetup)) +
										 (select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
							else
								vhoras_min = ((select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
			 		 		end if;
						end if;
					end if;
				
					vtotal_min = vtotal_min + vhoras_min;
					vhoras_min = (vhoras_min / 60);
					vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 ); --Transforma minutos em horas. Divido por 1000000 pois sao 4 casas decimais. Em vez de vim 2.5, vem 2.5000
				else
				-------
					vhorafinal = 23.59;
					vhoras = vhorafinal - vhrinisetup;
					vquantidade = 0;
				end if;
			else
			--
				vhoras = (select fn_Calculo_Horas(vhoras, vhrsetup , '+'));
			
				--OS 4297425
				SELECT EXTRACT(DOW FROM vdatainicio) into dia_semana + 1; --Soma 1 pois o "horfdia" inicia o domingo com o valor 1, e o sql retorna o domingo com valor 0.
				
				select horft1i, horft1f, horft2i, horft2f, horft3i, horft3f, horft4i, horft4f into v_horft1i, v_horft1f, v_horft2i, v_horft2f, v_horft3i, v_horft3f, v_horft4i, v_horft4f 
					from horfunc h where h.horfunc = new.operador::integer and h.horfdia = dia_semana;
				
				if v_horft1f > 0 then
					--if (vhrinisetup >= v_horft1i and vhorafinal <= v_horft1f) or (vhrinisetup >= v_horft2i and vhorafinal <= v_horft2f) or (vhrinisetup >= v_horft3i and vhorafinal <= v_horft3f)
					if (vhorafinal <= v_horft1f) or (vhrinisetup >= v_horft2i and vhorafinal <= v_horft2f) or (vhrinisetup >= v_horft3i and vhorafinal <= v_horft3f)
						or (vhrinisetup >= v_horft4i) then
						--or (vhrinisetup >= v_horft4i and vhorafinal <= v_horft4f) then
						
							vhoras_min = (select fn_transforma_horas_em_minutos(new.tempo_operacao)) + (select fn_transforma_horas_em_minutos(new.tempo_setup)); --Soma tempo de operacao e setup
							vhoras_min = (vhoras_min / 60);
							vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 );
					else
						
						--Hora inicial
						--if (vhrinisetup >= v_horft1i and vhrinisetup <= v_horft1f) then
						if (vhrinisetup <= v_horft1f) then
							vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
							v_turnoentrou = 1;
						end if;
					
						--if (vhrinisetup >= v_horft2i and vhrinisetup <= v_horft2f) then
						if (vhrinisetup <= v_horft2f) then
							vhoras_min = (select fn_transforma_horas_em_minutos(v_horft2f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
							v_turnoentrou = 2;
						end if;
					
						--if (vhrinisetup >= v_horft3i and vhrinisetup <= v_horft3f) then
						if (vhrinisetup <= v_horft3f) then
							vhoras_min = (select fn_transforma_horas_em_minutos(v_horft3f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
							v_turnoentrou = 3;
						end if;
					
						if (vhrinisetup >= v_horft4i) then
							vhoras_min = (select fn_transforma_horas_em_minutos(v_horft4f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
							v_turnoentrou = 4;
						end if;
					
						--Hora final
						if (vhorafinal >= v_horft2i and vhorafinal <= v_horft2f) then
						 		vhoras_min = vhoras_min + ((select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft2i)) );
						end if;
						if (vhorafinal >= v_horft3i and vhorafinal <= v_horft3f) then
							if v_turnoentrou = 1 then
						 	     vhoras_min = vhoras_min + (select fn_transforma_horas_em_minutos(v_horft2f) - (select fn_transforma_horas_em_minutos(v_horft2i)) + 
						 		 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft3i)) );
					 		else
					 			vhoras_min = vhoras_min + ( (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft3i)) );
					 		end if;
						end if;
						--if (vhorafinal >= v_horft4i and vhorafinal <= v_horft4f) then
						if (vhorafinal >= v_horft4i) then
							if v_turnoentrou = 1 then
								vhoras_min = vhoras_min + (select fn_transforma_horas_em_minutos(v_horft2f) - (select fn_transforma_horas_em_minutos(v_horft2i)) + 
											 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
											 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
							else
								if v_turnoentrou = 2 then
									vhoras_min = vhoras_min + ( (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
											 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
								else
									vhoras_min = vhoras_min + ( (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
								end if;
							end if;
						end if;
					
						--if (vhrinisetup >= v_horft1i and vhrinisetup <= v_horft1f) then
						/*if (vhrinisetup <= v_horft1f) then
							vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(vhrinisetup)) );
							if (vhorafinal >= v_horft2i and vhorafinal <= v_horft2f) then
							 		vhoras_min = vhoras_min + ((select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft2i)) );
							end if;
							if (vhorafinal >= v_horft3i and vhorafinal <= v_horft3f) then
						 	     vhoras_min = vhoras_min + (select fn_transforma_horas_em_minutos(v_horft2f) - (select fn_transforma_horas_em_minutos(v_horft2i)) + 
						 		 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft3i)) );
							end if;
							if (vhorafinal >= v_horft4i) then
							--if (vhorafinal >= v_horft4i and vhorafinal <= v_horft4f) then
								vhoras_min = vhoras_min + (select fn_transforma_horas_em_minutos(v_horft2f) - (select fn_transforma_horas_em_minutos(v_horft2i)) + 
											 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
											 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
							end if;
						end if;*/
					
						vtotal_min = vtotal_min + vhoras_min;
						vtempo_operacao = (select fn_transforma_horas_em_minutos(new.tempo_operacao));
						vtempo_setup    = (select fn_transforma_horas_em_minutos(new.tempo_setup));
						if vtotal_min > (vtempo_operacao + vtempo_setup) then
							vtotal_min = vhoras_min - (vtotal_min - (vtempo_operacao + vtempo_setup));
							vtotal_min = (vtotal_min / 60);
							vhoras = trunc(vtotal_min) + (( (vtotal_min - trunc(vtotal_min)) * 60) / 100 ); --Transforma minutos em horas
						else
							vhoras_min = (vhoras_min / 60);
							vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 );
						end if;
					
						/*
						vtotal_min = vtotal_min + vhoras_min;
						vhoras_min = (vhoras_min / 60);
						vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 );
						raise notice '2 - vtotal_min: %, new.tempo_operacao: %, new.tempo_setup: %, vhoras: %, vhoras_min: %', vtotal_min, new.tempo_operacao, new.tempo_setup, vhoras, vhoras_min;
						if vhoras > (new.tempo_operacao + new.tempo_setup) then
							vhoras = new.tempo_operacao + new.tempo_setup;
						end if;*/
					end if;
				end if;
			end if;
		else
			vhrinisetup = (SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N'));
		end if ;	
			--raise notice '2 %', new.ordem::integer;
			vhrinisetup = ROUND(vhrinisetup,2);
			IF (NEW.data_hora_fim <> ('0001-01-01 00:00:00')::timestamp) AND (NEW.processado = '0') THEN
	
			   INSERT INTO planilha (plaordem, pladata, plamaquina, plafuncion, plahrini, plahrfim, plahoras, plaopera, plaquant, plafase, plaprod, plaproc, plareserv)
				   VALUES(
					NEW.ordem::integer,
					vdatainicio, --current_date,
					vmaquina,
					NEW.operador::integer,
					vhrinisetup, --(SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N')),
					vhorafinal, --(SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N')), -- OS 4172124
					vhoras,
					voperacao,
					vquantidade, --NEW.qtde_produzido, -- OS 4172124
					vfase,
					vproduto,
					NEW.sequencia,
					(SELECT rprnumero FROM respror WHERE rprfase = vfase AND rproper = voperacao AND rprmaq = vmaquina AND rprproce = NEW.sequencia AND rprordem = NEW.ordem::integer));
				
				--raise notice '3 %', new.ordem::integer;
					
					if vdatainicio <> vdatafim then   -- OS 4172124
							vdatainicio = vdatainicio + interval '1 day'; 
							v_contaregistros = 1;
							while  vdatainicio <= vdatafim loop
								--OS 4327225
								v_temturno = (select coalesce(1,0) from horfunc h where h.horfunc = new.operador::integer limit 1);
								if v_temturno <> 1 then --Para garantir que caso seja nullo alimenta com zero.
									v_temturno = 0;
								end if;
								--
								
								--OS 4297425
								SELECT EXTRACT(DOW FROM vdatainicio) into dia_semana + 1; --Soma 1 pois o "horfdia" inicia o domingo com o valor 1, e o sql retorna o domingo com valor 0.
								
								select horft1i, horft1f, horft2i, horft2f, horft3i, horft3f, horft4i, horft4f into v_horft1i, v_horft1f, v_horft2i, v_horft2f, v_horft3i, v_horft3f, v_horft4i, v_horft4f 
									from horfunc h where h.horfunc = new.operador::integer and h.horfdia = dia_semana;
								
								if v_horft1f > 0 then
									v_temturno = 2; --OS 4327225
									vhorainicial = v_horft1i;
									if vdatainicio <> vdatafim then
										if v_horft4f > 0 then
											vhorafinal = v_horft4f;
										else
											if v_horft3f > 0 then
												vhorafinal = v_horft3f;
											else
												if v_horft2f > 0 then
													vhorafinal = v_horft2f;
												else
													vhorafinal = v_horft1f;
												end if;
											end if;
										end if;
																			
										vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(v_horft1i)) + 
												     (select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(v_horft2i)) +
												     (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
												 	 (select fn_transforma_horas_em_minutos(v_horft4f)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
									else
										vhorafinal = (SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N'));
										if (vhorafinal >= v_horft1i and vhorafinal <= v_horft1f) then
											vhoras_min = (select fn_transforma_horas_em_minutos(vhorafinal) - (select fn_transforma_horas_em_minutos(v_horft1i)) );
										else
											if (vhorafinal >= v_horft2i and vhorafinal <= v_horft2f) then
												vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(v_horft1i)) + 
												 		 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft2i)) );
								 		 	else
								 		 		if (vhorafinal >= v_horft3i and vhorafinal <= v_horft3f) then
								 		 			vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(v_horft1i)) + 
															 (select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(v_horft2i)) +
															 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft3i)) );
												else
													vhoras_min = (select fn_transforma_horas_em_minutos(v_horft1f) - (select fn_transforma_horas_em_minutos(v_horft1i)) + 
															 (select fn_transforma_horas_em_minutos(v_horft2f)) - (select fn_transforma_horas_em_minutos(v_horft2i)) +
															 (select fn_transforma_horas_em_minutos(v_horft3f)) - (select fn_transforma_horas_em_minutos(v_horft3i)) +
															 (select fn_transforma_horas_em_minutos(vhorafinal)) - (select fn_transforma_horas_em_minutos(v_horft4i)) );
								 		 		end if;
											end if;
										end if;
									end if;
									vtotal_min = vtotal_min + vhoras_min;
									
									if vdatainicio = vdatafim then
										vtempo_operacao = (select fn_transforma_horas_em_minutos(new.tempo_operacao));
										vtempo_setup    = (select fn_transforma_horas_em_minutos(new.tempo_setup));
										if vtotal_min > (vtempo_operacao + vtempo_setup) then
											v_percen_total = 100;
											v_contaregistros = v_contaregistros + 1;
											vtotal_min = (vtotal_min - (vtempo_operacao + vtempo_setup));
											--Faz o rateio da sobra do tempo total
											while 1 < v_contaregistros and v_percen_total <> 0 loop
												v_contaregistros = v_contaregistros - 1;
												v_plahora_min = 0;
												v_nova_data = vdatainicio - (v_contaregistros || 'day')::interval;
												v_plahora_min = fn_transforma_horas_em_minutos((select plahoras from planilha p where p.plaordem = NEW.ordem::integer and p.pladata = v_nova_data));
											
												if (v_plahora_min is not null) then	--4327225. Para desconsiderar os dias que o funcionario nao tem turno
													v_percen = ((v_plahora_min * 100) / vtotal_min);
													if v_percen > 10 then
														v_percen = v_percen - 10;
													end if;
													if v_percen > v_percen_total then
														v_percen = v_percen_total;
													end if;
													v_plahora_min = v_plahora_min - (vtotal_min * v_percen) / 100;
													v_percen_total = v_percen_total - v_percen;
												
													v_plahora_min = (v_plahora_min / 60);
													vhoras = trunc(v_plahora_min) + (( (v_plahora_min - trunc(v_plahora_min)) * 60) / 100 ); --Transforma minutos em horas
													update planilha set plahoras = vhoras where plaordem = NEW.ordem::integer and pladata = v_nova_data;
												end if;
											end loop;
											if v_percen_total > 0 then
												vtotal_min = vhoras_min - (vtotal_min * v_percen_total) / 100;
											else 
												vtotal_min = vhoras_min;
											end if;
											vtotal_min = (vtotal_min / 60);
											vhoras = trunc(vtotal_min) + (( (vtotal_min - trunc(vtotal_min)) * 60) / 100 ); --Transforma minutos em horas
										else
											vhoras_min = (vhoras_min / 60);
											vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 );
										end if;
									else
										v_contaregistros = v_contaregistros + 1;
										vhoras_min = (vhoras_min / 60);
										vhoras = trunc(vhoras_min) + (( (vhoras_min - trunc(vhoras_min)) * 60) / 100 ); --Transforma minutos em horas
									end if;
								else
								-------
									if (v_temturno = 0) then --OS 4327225. Somente se o funcionario nao tiver NENHUM dia da semana com turno.
										v_temturno = 2; --OS 4327225
										if vdatainicio <> vdatafim then
											vhorainicial = 00.00;
											vhorafinal = 23.59;	
											vhoras = 23.59;
										else
											vhorainicial = 00.00;
											vhorafinal = (SELECT fn_Converte_Hora(NEW.data_hora_fim, ('0001-01-01 00:00:00')::timestamp, 'N'));
											vhoras = vhorafinal;
										end if;
									end if;
								end if;
							
								if (v_temturno = 2) then
									INSERT INTO planilha (plaordem, pladata, plamaquina, plafuncion, plahrini, plahrfim, plahoras, plaopera, plaquant, plafase, plaprod, plaproc, plareserv)
						   			VALUES(
									NEW.ordem::integer,
									vdatainicio, 
									vmaquina,
									NEW.operador::integer,
									vhorainicial,
									vhorafinal,
									vhoras,
									voperacao,
									case
									  when vdatainicio = vdatafim then	NEW.qtde_produzido
									  else 0
									end,  
									vfase,
									vproduto,
									NEW.sequencia,
									(SELECT rprnumero FROM respror WHERE rprfase = vfase AND rproper = voperacao AND rprmaq =
									vmaquina AND rprproce = NEW.sequencia AND rprordem = NEW.ordem::integer));						
								end if;
							
								vdatainicio = vdatainicio + interval '1 day';
							end loop;
						
						end if;
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

				    --vhoraAtual = (select current_time::char(8));
				    vhoraAtual = '';
				   	vhoraAtual = (select clock_timestamp()::time::char(8));
				    vcount = 0;
				    vcount = coalesce((SELECT 1
						 FROM logaces
					  WHERE lgaorigem = 'GERAL'
						 AND lgadata = current_date
						 AND lgahora = vhoraAtual),0);
					
				    IF (vcount > 0) then
				    	--vhoraAtual = (SELECT current_time::time::char(5));
					    --vcount = vcount + 1;
					    --vhoraAtual = vhoraAtual || vcount;
					   	loop
					   		if (vcount > 940) then
					    		PERFORM pg_sleep(1);
					    	end if;
							vcount = vcount + 1;
							vhoraAtual = (select clock_timestamp()::time::char(5)) || vcount;
							if (SELECT count(*)
								FROM logaces
								WHERE lgaorigem = 'GERAL'
								AND lgadata = current_date
								AND lgahora = vhoraAtual) = 0 then
									exit;
							end if;
						end loop;
				    END IF;

				    INSERT INTO logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao)
					VALUES(
						'GERAL',
						(SELECT current_date),
						vhoraAtual,
						'ColetorP&F',
						'Incluido planilhamento de producao para a ordem ' || NEW.ordem ||', no processo ' || NEW.sequencia ||' pela integracao com coletores P&F.',
						(SELECT substring(dadversao,1,9) FROM dadosemp LIMIT 1));
			
			ELSE  -- Hora final nao preenchida
				vhoras = 0;
				IF (NEW.data_hora_fim = ('0001-01-01 00:00:00')::timestamp) AND (NEW.processado = '0') and ((SELECT rdcolin FROM pareqd2 WHERE pareqcod = 1) = 'S' or (SELECT rdcolin FROM pareqd2 WHERE pareqcod = 1) = 'A') THEN
				 --AND (SELECT rdcolin FROM notparam WHERE notparam = 1) = 'S' THEN
				   --vdatainicio = coalesce(vdatainicio, NEW.data_hora_inicio::date);
				   INSERT INTO planilha (plaordem, pladata, plamaquina, plafuncion, plahrini, plahrfim, plahoras, plaopera, plaquant, plafase, plaprod, plaproc, plareserv)
					   VALUES(
						NEW.ordem::integer,
						vdatainicio,  -- Os 4172124
						vmaquina,
						NEW.operador::integer,
						vhrinisetup,--(SELECT fn_Converte_Hora(NEW.data_hora_inicio, ('0001-01-01 00:00:00')::timestamp, 'N')),
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
						
						vhoraAtual = '';
						vhoraAtual = (select clock_timestamp()::time::char(8));
					    vcount = 0;
					    vcount = coalesce((SELECT 1
						 FROM logaces
					  WHERE lgaorigem = 'GERAL'
						 AND lgadata = current_date
						 AND lgahora = vhoraAtual),0);
				
						IF (vcount > 0) then
							--vhoraAtual = (SELECT current_time::time::char(5));
							loop
								if (vcount > 940) then
						    		PERFORM pg_sleep(1);
						    	end if;
								vcount = vcount + 1;
								vhoraAtual = (select clock_timestamp()::time::char(5)) || vcount;
								if (SELECT count(*)
									FROM logaces
									WHERE lgaorigem = 'GERAL'
									AND lgadata = current_date
									AND lgahora = vhoraAtual) = 0 then
										exit;
								end if;
							end loop;
						END IF;

						INSERT INTO logaces (lgaorigem, lgadata, lgahora, lgausuar, lgatexto, lgaversao)
						VALUES(
						'GERAL',
						(SELECT current_date),
						vhoraAtual,
						'ColetorP&F',
						'Incluido planilhamento de producao para a ordem ' || NEW.ordem ||', no processo ' || NEW.sequencia ||' pela integracao com coletores P&F.',
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
