-- Function: p_critica_negativos(character, character, numeric, integer, numeric, numeric, character, character, date)

-- DROP FUNCTION p_critica_negativos(character, character, numeric, integer, numeric, numeric, character, character, date);

CREATE OR REPLACE FUNCTION p_critica_negativos(pusuario character, plote character, psomentelote numeric, pordem integer, pfase numeric, pquanti numeric, pusunega character, ptipocritica character, pdata date)
  RETURNS void AS
$BODY$
declare

	v_vrows int;
	v_currentRow int;
	v_rordem numeric(7,0);
	v_rfase smallint;
	v_rproduto char(16);
	v_produto_req_nivel smallint;
	v_rrequisitado numeric(15,4);
	v_rproduto_ordem char(16);
	v_produto_ordem_nivel smallint;
	v_rproduto_ordem_ant char(16); 
	v_qtd_passagem_atual numeric(15,4);
	v_qtd_passagem_ant numeric(15,4);	
	v_saldo_item numeric(15,4);
        v_saldo_simu numeric(15,4);
	v_saldo_data date;
	v_cordem char(9);
	v_tem_negativos boolean;	
	v_ordem_ant numeric(7,0);
	v_fase_ant smallint;
	v_fase_fim smallint;
    v_ret_proorigem char(1);		
	v_ini_row int;
	v_fim_row int;
	v_ret_current_row int;
	v_ret_produto char(16);
	v_ret_quanti numeric(15,4);	
	v_ret_quanti_soma numeric(15,4);
	v_ret_fase smallint;  --Alvaro para utilizar na atualizacao da tabela umgasto 
	v_ret_cordem char(9); --Alvaro para utilizar na atualizacao da tabela umgasto	
	v_obs char(200);
	v_ret_quanti_ofs numeric(15,4); --Marcos Alles, OS 4028923, 2023-12-12
	verifica_valor numeric(15,4); 
Begin
      
   DROP TABLE IF EXISTS saldo_table;

   CREATE temporary TABLE saldo_table
  (
    produto char(16),
    saldo numeric(15,4),
    data_saldo date
  );

  DROP TABLE IF EXISTS ordens_requisicao;

  CREATE temporary TABLE ordens_requisicao
  (
	id serial,
	ordem numeric(7,0),
	fase smallint,
	produto char(16),
	nivel_req smallint, --Alvaro 03/03/2021 para saber nivel do produto requisitado e comparar com o nivel do produto da ordem
	origem_req char(1), --Alvaro 03/03/2021 para saber a origem do produto requisitado
	arequisitar numeric(15,4),
	produto_ordem char(16),	
	nivel smallint,        
	qtd_passagem numeric(15,4),
	deposito smallint,
	saldo_ordem numeric(15,4),
	fasefim smallint,
	saldo_somado numeric(15,4) --Marcos Alles, OS 4028923, 2023-12-12
  );

  DELETE FROM umgasto um
	WHERE um.umgausu = pusunega;

	IF psomentelote = 1 THEN

		INSERT INTO ordens_requisicao(ordem, fase, produto, nivel_req, origem_req, arequisitar, produto_ordem, qtd_passagem,
nivel, deposito, saldo_ordem, saldo_somado) --Alvaro 03/03/2021 inclusao do atributo nivel_req --Marcos Alles, OS 4028923, 2023-12-12 saldo_somado
			SELECT
				req.reqord,
				req.reqfase,
				req.reqproduto,
                                pro.pronivelb, -- Alvaro 03/03/2021 incluido pr.pronivelb para produto requisitado.
                                pro.proorigem, --Alvaro 03/03/2021 para saber a origem do produto requisitado 
				(req.rqoquanti - (SELECT fn_reserva_atendida_produto_of(req.reqord, req.reqproduto))),
				orde.ordproduto,
				(orde.ordquanti - (SELECT fn_quantidade_passada_fase_of(req.reqord, fas.fsorfase, 1))),
				p.pronivelb,   -- Alvaro 03/03/2021 so comentado que e o nivel do produto da ordem.								
				req.reqdepo,
				(orde.ordquanti - (SELECT fn_quantidade_passada_fase_of(req.reqord, fas.fsorfase, 0))),
				(orde.ordquanti - (SELECT fn_quantidade_passada_fase_of(req.reqord, fas.fsorfase, 0))) --Marcos Alles, OS 4028923, 2023-12-12
			FROM reqordem req				
				INNER JOIN (SELECT o.ordem, o.orddtence, o.ordquanti, o.ordproduto, o.orddeposit FROM ordem o WHERE o.lotcod
= plote) AS orde ON (orde.ordem = req.reqord)
                                --Alvaro 17/02/21 inclusao do orddtence no JOIN
				INNER JOIN (SELECT f.fsororde, f.fsorfase FROM fasord f) AS fas ON (fas.fsororde = orde.ordem
AND (pfase = 0 OR fas.fsorfase <= pfase)) --Marcos 07/11/23 inclusao do sinal de menor para considerar fases ate a informada nas passagens em lote
				INNER JOIN (SELECT pr.produto, pr.grupo, pr.prorqman, pr.pronivelb, pr.proorigem from produto pr) AS pro ON (pro.produto =
req.reqproduto) -- Alvaro 03/03/2021 incluido pronivelb e proorigem para produto requisitado.
				INNER JOIN (SELECT fs.fase, fs.fasreqaut from fases fs) AS fse ON (fse.fase = req.reqfase),
				produto p
			WHERE req.reqord = orde.ordem
			AND req.reqfase = fas.fsorfase
			AND fse.fasreqaut = 'S'
			AND p.produto = orde.ordproduto
			AND pro.grupo <> 999
			AND (orde.ordquanti - (SELECT fn_quantidade_passada_fase_of(req.reqord, fas.fsorfase, 1))) <> 0
			--AND (req.rqoquanti - (SELECT fn_reserva_atendida_produto_of(req.reqord, req.reqproduto))) <> 0
			AND ( (req.rqoquanti - (SELECT fn_reserva_atendida_produto_of(req.reqord, req.reqproduto))) <> 0 OR orde.orddtence = '0001-01-01' )
			--Alvaro 17/02/21 para quando nao tiver nada para requisitar, verifica OF em aberto, pois pode ter sido requisitado manualmente
			AND pro.prorqman <> 'S'
			ORDER BY p.pronivelb DESC, req.reqfase, req.reqord;
	ELSE

		IF trim(plote) <> '' THEN
			INSERT INTO ordens_requisicao(ordem, fase, produto, arequisitar, produto_ordem, qtd_passagem,
nivel, deposito, saldo_ordem)
				SELECT
					req.reqord,
					req.reqfase,
					req.reqproduto,
					(req.rqoquanti - (SELECT fn_reserva_atendida_produto_of(um.umororde, req.reqproduto))),
					orde.ordproduto,
					um.umorqua,
					p.pronivelb,
					req.reqdepo,
					(orde.ordquanti - (SELECT fn_quantidade_passada_fase_of(um.umororde, fas.fsorfase, 0)))
				FROM reqordem req
					INNER JOIN (SELECT u.umoresta, u.umororde, u.umormar, u.umorqdof, u.umooror, u.umorqua FROM
umordem u) AS um
						ON (um.umoresta = pusuario AND um.umormar = '+' AND um.umorqdof <> 0 AND trim(um.umooror) <>
'N')
					INNER JOIN (SELECT o.ordem, o.ordquanti, o.ordproduto, o.orddeposit FROM ordem o) AS orde ON
(orde.ordem = um.umororde)
					INNER JOIN (SELECT f.fsororde, f.fsorfase FROM fasord F) AS fas ON (fas.fsororde = um.umororde
AND (pfase = 0 or fas.fsorfase = pfase))
					INNER JOIN (SELECT pr.produto, pr.grupo, pr.prorqman from produto pr) AS pro ON (pro.produto =
req.reqproduto)
				INNER JOIN (SELECT fs.fase, fs.fasreqaut from fases fs) AS fse ON (fse.fase = req.reqfase),
					produto p
				WHERE req.reqord = um.umororde
				AND req.reqfase = fas.fsorfase
			        AND fse.fasreqaut = 'S'
				AND p.produto = orde.ordproduto
				AND pro.grupo <> 999
				AND (orde.ordquanti - (SELECT fn_quantidade_passada_fase_of(um.umororde, fas.fsorfase, 1))) <> 0
				AND (req.rqoquanti - (SELECT fn_reserva_atendida_produto_of(um.umororde, req.reqproduto))) <> 0
				AND pro.prorqman <> 'S'
				ORDER BY p.pronivelb desc, req.reqfase, req.reqord;
		ELSE

			INSERT INTO ordens_requisicao(ordem, fase, produto, arequisitar, produto_ordem, qtd_passagem,
nivel, deposito, saldo_ordem)
				SELECT
					req.reqord,
					req.reqfase,
					req.reqproduto,
					(req.rqoquanti - (SELECT fn_reserva_atendida_produto_of(req.reqord, req.reqproduto))),
					orde.ordproduto,
					pquanti,
					p.pronivelb,
					req.reqdepo,
					(orde.ordquanti - (SELECT fn_quantidade_passada_fase_of(req.reqord, fas.fsorfase, 0)))
				FROM reqordem req				
					INNER JOIN (SELECT o.ordem, o.ordquanti, o.ordproduto, o.orddeposit FROM ordem o) as orde on
(orde.ordem = req.reqord)
					INNER JOIN (SELECT f.fsororde, f.fsorfase FROM fasord f) AS fas ON (fas.fsororde = orde.ordem
AND (pfase = 0 OR (fas.fsorfase = pfase and psomentelote <> 2) or (fas.fsorfase <= pfase and psomentelote = 2) )) --Marcos, OS 4239225, 2025-02-20 - Adicionado "psomentelote <> 2" e "or (fas.fsorfase <= pfase and psomentelote = 2) ))"
					INNER JOIN (SELECT pr.produto, pr.grupo, pr.prorqman from produto pr) AS pro ON (pro.produto =
req.reqproduto)
				INNER JOIN (SELECT fs.fase, fs.fasreqaut from fases fs) AS fse ON (fse.fase = req.reqfase),
					produto p
				WHERE req.reqord = pordem
				AND req.reqfase = fas.fsorfase
			        AND fse.fasreqaut = 'S'
				AND p.produto = orde.ordproduto
				AND pro.grupo <> 999
				AND (orde.ordquanti - (SELECT fn_quantidade_passada_fase_of(req.reqord, fas.fsorfase, 1))) <> 0
				AND (req.rqoquanti - (SELECT fn_reserva_atendida_produto_of(req.reqord, req.reqproduto))) <> 0
				AND pro.prorqman <> 'S'
				ORDER BY p.pronivelb DESC, req.reqfase, req.reqord;
		END IF;
	END IF;

	
	INSERT INTO saldo_table(produto, saldo, data_saldo)
		SELECT
			q2.produto,
			(SELECT fn_saldo_produto(pdata, q2.produto, q2.deposito, 0, 0)),
			pdata
		FROM
			((SELECT distinct(q1.produto), q1.deposito FROM ordens_requisicao q1)
			UNION
			(SELECT distinct(q1.produto_ordem), q1.deposito FROM ordens_requisicao q1)) q2;
			
	INSERT INTO saldo_table(produto, saldo, data_saldo)
		SELECT
			q3.priproduto,
			(SELECT fn_saldo_produto(q3.pridata, q3.priproduto, q3.prideposit, 0, 0)),
			q3.pridata
		FROM
			(SELECT DISTINCT(t.priproduto), t.prideposit, t.pridata FROM toqmovi t
				WHERE t.priproduto in (select produto from saldo_table)
				AND t.pritransac in (3, 4, 14)
				AND t.pridata > pdata) q3;

   -- Alvaro para os casos em que o negativo esta na ultima OF da lista do temporario, pois neste caso, o loop nao teria uma nova OF para comparar que fez a mudanca
   -- do numero da OF na clausula que esta mais abaixo IF v_rordem <> v_ordem_ant AND v_fase_ant = v_fase_fim AND v_fase_ant <> 0 THEN
   IF psomentelote = 1 THEN       
   			INSERT INTO ordens_requisicao (ordem, fase, produto, arequisitar, produto_ordem, qtd_passagem, nivel, deposito, saldo_ordem)
                              values (9999999,99,'',1,'',1,0,0,1);
   END IF;	v_currentRow = 1;
	v_vrows = (SELECT max(o.id) FROM ordens_requisicao o);
	v_rproduto_ordem_ant = '';
	v_tem_negativos = FALSE;
	v_ordem_ant = 0;
	v_fase_ant = 0;

	WHILE v_currentRow <= v_vrows LOOP
	
		UPDATE ordens_requisicao
			SET arequisitar = ( SELECT
						CASE
							WHEN (SELECT p.proarreq FROM produto p WHERE p.produto = o.produto) = 'S' AND
ROUND(((arequisitar / saldo_ordem) * qtd_passagem), 0) <= saldo_ordem THEN ROUND(((arequisitar /
saldo_ordem) * qtd_passagem), 0)
							WHEN (SELECT p.proarreq FROM produto p WHERE p.produto = o.produto) = 'S' AND
ROUND(((arequisitar / saldo_ordem) * qtd_passagem), 0) > saldo_ordem THEN saldo_ordem
							ELSE (arequisitar / saldo_ordem) * qtd_passagem
						END
					FROM ordens_requisicao o
					WHERE o.id = v_currentRow)
		WHERE id = v_currentRow;
			
		SELECT o.ordem,
		       o.fase,
		       o.produto,
		       o.nivel_req,  
		       o.arequisitar,
		       o.qtd_passagem,
		       o.produto_ordem,
		       o.nivel 
	          INTO 
	               v_rordem, 
	               v_rfase, 
	               v_rproduto, 
	               v_produto_req_nivel,
	               v_rrequisitado, 
	               v_qtd_passagem_atual,
	               v_rproduto_ordem,
	               v_produto_ordem_nivel
			FROM ordens_requisicao o
		WHERE o.id = v_currentRow ORDER BY o.id;

		IF psomentelote = 1 and pfase <> 0 then		
			if (select 1 from fasord f where f.fsororde = v_rordem and f.fsorfase > pfase limit 1) = 1 then
				v_qtd_passagem_atual = 0;
			end if;
		end if;

		v_currentRow = v_currentRow + 1;
		
		if v_ordem_ant <> 0 then
           v_fase_fim = (SELECT max(rq.reqfase) FROM reqordem rq WHERE rq.reqord = v_ordem_ant and ( select produto.grupo from produto where produto = reqproduto ) <> 999 and
                        (select fasreqaut from fases where reqfase = fase ) = 'S');
		else
		    v_fase_fim = 0;
		end if;
		
		IF v_rordem <> v_ordem_ant AND v_fase_ant = v_fase_fim AND v_fase_ant <> 0 THEN		   
			IF v_tem_negativos = TRUE THEN
				v_ini_row := (SELECT MIN(oa.id) FROM ordens_requisicao oa WHERE oa.ordem = v_ordem_ant);
				v_fim_row := (SELECT MAX(oa.id) FROM ordens_requisicao oa WHERE oa.ordem = v_ordem_ant);
				v_ret_current_row :=  v_ini_row;
	            
				WHILE v_ret_current_row <= v_fim_row LOOP				        
					SELECT o.produto,
					       o.arequisitar,
                                               o.fase, 
                                               o.origem_req 
                                             INTO 
                                               v_ret_produto, 
                                               v_ret_quanti, 
                                               v_ret_fase, 
                                               v_ret_proorigem 
                                               --Alvaro incluido v_ret_fase para utilizar na atualizacao da tabela umgasto
                                               --Alvaro 03/03/2021 incluido v_ret_proorigem para tratar ajuste abaixo
					FROM ordens_requisicao o
					    WHERE o.ordem = v_ordem_ant
					    AND o.id = v_ret_current_row;

					--Alvaro para tratar retornos nulos    
					If v_ret_produto is null then
					   v_ret_produto = '';
					   v_ret_quanti  = 0;
					   v_ret_fase    = 0;
					End If;
					   
					                    --Raise notice '%', v_ret_current_row::text|| ' ' || v_ordem_ant || ' '||v_ret_produto||' '||v_ret_quanti::text;

                                        --v_ret_current_row = v_ret_current_row + 1;

                                        If ( select count(*) from  ordens_requisicao where produto_ordem = v_ret_produto ) > 0 then
	                                           -- Alvaro 03/03/2021 parra produtos que tenham OF no lote
	                           
                                        	--Marcos Alles, OS 4028923, 2023-12-12
                                        	IF psomentelote = 1 THEN   
	                                        	select saldo into v_saldo_simu from saldo_table where produto = v_ret_produto order by data_saldo limit 1; --Busca o saldo atual do produto
	                                         	SELECT SUM(saldo_somado) into v_ret_quanti_ofs --Soma o saldo restante das OFs (filtrando apenas as que ainda tem o saldo maior que zero)
								FROM (
								    SELECT DISTINCT produto_ordem, saldo_somado
								    FROM ordens_requisicao
								    WHERE produto_ordem = v_ret_produto and saldo_somado >= 0
								) AS saldo_das_ofs
								GROUP BY produto_ordem;
							
								--Altera o saldo restante da OF somando o saldo do produto com o resultado da subtracao "saldo da OF menos a quantidade requisitada"
								update ordens_requisicao set saldo_somado = v_saldo_simu + (saldo_somado - v_ret_quanti) where produto_ordem = v_ret_produto; 
							
								if v_ret_quanti_ofs is null then --Se estiver nullo alimenta com 0
									v_ret_quanti_ofs = 0;
								end if;
								UPDATE saldo_table
							SET saldo = saldo + v_ret_quanti_ofs -- "v_ret_quanti_ofs" pois o "v_ret_quanti" como ? feito no else 
											     -- e(acento) o saldo a ser requisitado, porem nessa tabela grava o saldo do produto, logo, deve ser somado o saldo das OFs
											     -- ja que em processos mais abaixo ja foi considerado o saldo requistado.
							WHERE produto = v_ret_produto;
						
							--Marcos Alles, OS 4278525, 15/05/2025 - Quando verificava o saldo das OFs, mesmo que ficasse positivo, o sistema nao estava atualizando a tabela "umgasto" com o saldo correto, mas
							--sempre deixando o saldo a requisitar do produto, ficando incoerente o valor.
							select saldo into verifica_valor from saldo_table where produto = v_ret_produto order by data_saldo limit 1;
							v_cordem = (lpad(CAST(v_ordem_ant AS CHAR(7)),7,' ') || lpad(CAST(v_fase_ant AS CHAR(2)),2,''))::character(15);
							UPDATE umgasto
								SET
									umgaqtre = verifica_valor
							WHERE umgausu = pusunega AND umgaccus = 'XXXXX' AND umgaplan = v_cordem AND umgaprod = v_ret_produto;
						else
						-----------------------------------------
							UPDATE saldo_table
							    SET saldo = saldo + v_ret_quanti 
								WHERE produto = v_ret_produto;
						end if;
											  
	                                           --Alvaro 03/03/2021 para saber o sando que ficou 
						   					   select saldo into v_saldo_simu from saldo_table where produto = v_ret_produto order by data_saldo limit 1 ; 
	
						        			   --Raise notice '%', v_ret_current_row::text|| ' ' || v_ordem_ant || ' '||v_ret_produto||' '||v_ret_quanti_ofs::text||' '||v_saldo_simu::text;
						       
	                                           --Alvaro para atualizar a tabela umgasto que nao estava sendo atualizada quando entrava aqui
	                                           If v_ret_proorigem = 'F' then 
		                                              -- Alvaro 03/03/2021 sao produto fabricados
		                                              v_ret_cordem = (lpad(CAST(v_ordem_ant AS CHAR(7)),7,' ') || lpad(CAST(v_ret_fase AS CHAR(2)),2,''))::character(15);
		                                             -- UPDATE umgasto SET umgaqtre = v_saldo_simu -- umgaqtre + v_ret_quanti -- *MAX
				                              		 --Alvaro 03/03 v_saldo_simu para saber o sando que ficou 
				                              		 --WHERE umgausu = pusunega AND umgaccus = 'XXXXX' AND umgaplan = v_ret_cordem AND umgaprod = v_ret_produto;
                               				  End If;
                                        End If;    
                   v_ret_current_row = v_ret_current_row + 1;
				END LOOP;
				v_tem_negativos := FALSE;
			ELSE
				UPDATE saldo_table
					SET saldo = saldo + v_qtd_passagem_ant
				WHERE produto = v_rproduto_ordem_ant;
	
			END IF;
		END IF;
		
		UPDATE saldo_table
			SET saldo = saldo - v_rrequisitado
		WHERE produto = v_rproduto;	
		
		SELECT s.saldo, s.data_saldo into v_saldo_item, v_saldo_data
			from saldo_table s
		WHERE s.produto = v_rproduto
		AND s.saldo < 0
		ORDER BY s.data_saldo
		LIMIT 1;
		IF v_saldo_item < 0 THEN			
		   If v_produto_ordem_nivel >= v_produto_req_nivel then
		       --Raise notice '%', v_rordem::text||' '||v_rproduto_ordem||' '||v_produto_ordem_nivel::text||' '||v_rproduto||' '||v_produto_req_nivel::text;
		        v_obs = 'OF: '||v_rordem::text||' Produto: '||v_rproduto_ordem||' Requisita no nivel '||v_produto_ordem_nivel::text||' o produto '||v_rproduto||' que e fabricado no nivel '||v_produto_req_nivel::text;
		   else
			v_obs = '';
                   End If;
						
			v_tem_negativos = TRUE;
			
			v_cordem = (lpad(CAST(v_rordem AS CHAR(7)),7,' ') || lpad(CAST(v_rfase AS CHAR(2)),2,'
'))::character(15);
			
			IF EXISTS(SELECT 1 FROM umgasto u
						WHERE u.umgausu = pusunega AND u.umgaccus = 'XXXXX' AND u.umgaplan = v_cordem AND u.umgaprod =
v_rproduto) THEN
				UPDATE umgasto
					SET
						umgaqtre = umgaqtre + v_saldo_item,	
						umgaqtde = umgaqtde + v_rrequisitado
				WHERE u.umgausu = pusunega AND u.umgaccus = 'XXXXX' AND u.umgaplan = v_cordem AND u.umgaprod =
v_rproduto;
			
			ELSE
				INSERT INTO umgasto(umgausu, umgaccus, umgaplan, umgaprod, umgaqtre, umgaqtde, umgavlre,umgadata,umgaobs)
				VALUES(
					pusunega,
					'XXXXX',
					v_cordem,
					v_rproduto,
					v_saldo_item,
					v_rrequisitado,
					v_qtd_passagem_atual,
					v_saldo_data,
					v_obs
					);
			END IF;

			--DESMARCA PARA A PASSAGEM, QUANDO FOR POR OF EM LOTE.
			UPDATE umordem
				SET umormar = ''
			 WHERE umoresta = pusuario
			 AND umororde = v_rordem
			 AND ptipocritica = 'N';

		END IF;
		
		v_rproduto_ordem_ant = v_rproduto_ordem;
		v_qtd_passagem_ant = v_qtd_passagem_atual;
		v_ordem_ant = v_rordem;
		v_fase_ant = v_rfase;
		
	END LOOP;
	
   DELETE FROM umgasto
   WHERE umgausu = pusunega and  umgaqtre >= 0; --Alvaro para nao ficar registros que nao tenha negativo
		
End;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION p_critica_negativos(character, character, numeric, integer, numeric, numeric, character, character, date) SET search_path=public, pg_temp;

ALTER FUNCTION p_critica_negativos(character, character, numeric, integer, numeric, numeric, character, character, date)
  OWNER TO postgres;
