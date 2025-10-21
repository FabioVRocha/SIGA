    DROP FUNCTION IF EXISTS fn_status_assistec(p_assistec integer);
    CREATE OR REPLACE FUNCTION fn_status_assistec(p_assistec integer)
    RETURNS integer AS
    $BODY$
    DECLARE
    	v_origem character(10);
    	v_status character(2);
    	v_status2 character(2);
    	v_ip character(20);
    	v_porta integer;
    	v_usuario character(10);
    	ordem_status character(2);
    	ordem_status2 character(2);
    	v_aprova character(2);
    	v_situa character(2);
    BEGIN
    	-- '01' - Assistencia Nao Aprovada
    	-- '02' - Assistencia Aprovada
    	-- '03' - Vinculo com OF Estatica
    	-- '04' - Vinculo com OF em Processo
    	-- '05' - Vinculo com OF Encerrada
    	-- '06' - Vinculo com OF Com Problema
    	-- '07' - Atendido Parcial
    	-- '08' - Atendido Total
    	-- '09' - Vinculo com Expedicao
    	-- '10' - Assistencia Cancelada
    	v_ip = (select inet_client_addr());
    	v_porta = (select inet_client_port());
    	-- Busca o Usuario Logado no sistema,
    	-- pela informacao do IP e Porta gravados na Userid
    	v_usuario = (select uiusuario
    	              from userid
    	             where uidip = v_ip
    	               and uidport = v_porta
    	               and uidlocal = 1 limit 1);
    	--
    	-- Se NAO existe o registro na tabela de Status da Assistencia
    	insert into assstatu (assassiste, assastatus, assdta, asshora, assusua)
    	select p.assistec,
    	       (case
    		   when p.asssitua = 'NA' then '01'
    		   when p.asssitua = 'CA' then '10'
    		   else '02'
    		end),
    	       current_date,
    	       localtime(0),
    	       v_usuario
    	from assistec p
    	where p.assistec = p_assistec
    	  and not exists (select 1 from assstatu ps where ps.assassiste = p.assistec);
    	--
    	v_status = '99';
    	-- Sera verificado se Assistencia e NAO APROVADO ou APROVADO
    	v_aprova = (select asssitua from assistec p where p.assistec = p_assistec and p.asssitua <> 'CA' limit
    1);
    	if v_aprova = 'N' then
    		v_status = '01';
    	else
    		v_status = '02';
    	end if;
    	-- Sera verificado se esta relacionada a OF
    	ordem_status2 = '99';
    	for ordem_status in select o.ordlotstat
    			    from acaorde4 a, ordem o
    			    where a.acaorasco = p_assistec
    			      and a.acaoorde = o.ordem
    	loop
    		case when ordem_status = 'ES' then v_status2 = '03'; -- ESTATICA
    		     when ordem_status = 'FA' then v_status2 = '04'; -- EM PROCESSO
    		     when ordem_status = 'EP' then v_status2 = '04'; -- EM PROCESSO
    		     when ordem_status = 'EC' then v_status2 = '05'; -- ENCERRADA
    		     else
    		end case;
    		if ordem_status2 = '99' or ordem_status2 < v_status2 then
    			case when ordem_status = 'ES' then v_status = '03'; -- ESTATICA
    			     when ordem_status = 'FA' then v_status = '04'; -- EM PROCESSO
    			     when ordem_status = 'EP' then v_status = '04'; -- EM PROCESSO
    			     when ordem_status = 'EC' then v_status = '05'; -- ENCERRADA
    			     else
    			end case;
    			ordem_status2 = v_status;
    		end if;
    	end loop;
    	-- Sera verificado se tem relacao com EXPEDICAO
    	if (select 1 from prjexsi1 pr where pr.prjessepa = p_assistec limit 1) > 0 then
    		v_status = '09';
    	end if;
    	if (select 1 from projped1 po where po.prjpedido = p_assistec limit 1) > 0 then
    		v_status = '09';
    	end if;
    	-- Sera verificado se esta atendido PARCIAL ou TOTAL
    	v_situa = (select p.assstatus from assistec p where p.assistec = p_assistec limit 1);
    	case when v_situa = 'AP' then v_status = '07';
    	     when v_situa = 'AT' then v_status = '08';
    	     else
    	end case;
    	-- Sera verificado se Status da Assistencia e CANCELADO
    	if (select p.asssitua from assistec p where p.assistec = p_assistec ) = 'CA' then
    		v_status = '10';
    	end if;
    	if v_status <> '99' then
    		update assstatu set assastatus = v_status,
    		    assdta = current_date,
    		    asshora = localtime(0),
    		    assusua = v_usuario
    		 where assassiste = p_assistec;
    	end if;
    	Return 1;
    END;
    $BODY$
      LANGUAGE plpgsql VOLATILE
      COST 100;
    ALTER FUNCTION fn_status_assistec(integer)
      OWNER TO postgres;