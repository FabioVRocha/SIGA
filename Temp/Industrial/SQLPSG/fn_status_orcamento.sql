-- Function: fn_status_orcamento(integer, character)

-- DROP FUNCTION fn_status_orcamento(integer, character);

CREATE OR REPLACE FUNCTION fn_status_orcamento(p_orcamento integer, p_status character)
  RETURNS integer AS
$BODY$
DECLARE
	v_status character(2);
	v_ip character(20);
	v_porta integer;
	v_usuario character(10);
	v_aprova character(2);
BEGIN
	-- '07' - Atendido Parcial
	-- '08' - Atendido Total
    -- '10' - Orcamento Cancelado
    -- '97' - Orcamento Pendente
	-- 'D'  - Orcamento Perdido
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
	-- Se NAO existe o registro na tabela de Status do Pedido
	insert into ostatus (osorcacod, osstatus, osdta, oshora, osusua)
	select o.orcacod,
	       (case
		   when o.orcastatus = 'A' then '08'
		   when o.orcastatus = 'P' then '07'
           when o.orcastatus = 'D' then 'D'
           when o.orcastatus = ' ' then '97'
           when o.orcastatus = 'C' then '10'
		   else '97'
		end),
	       current_date,
	       localtime(0),
	       v_usuario
	from orcament o
	where o.orcacod = p_orcamento
	  and not exists (select 1 from ostatus ps where ps.osorcacod = o.orcacod);
	--
	v_status = '99';
	-- Sera verificado se Pedido e NAO APROVADO ou APROVADO
	--v_aprova = (select orcastatus from orcament o where o.orcacod = p_orcamento limit 1);
	v_aprova = p_status;
	if v_aprova = 'A' then
    	v_status = '08';
	end if;
	if v_aprova = 'P' then
		v_status = '07';
	end if;
	if v_aprova = 'D' then
		v_status = 'D';
	end if;
	if v_aprova = ' ' then
		v_status = '97';
	end if;
	if v_aprova = 'C' then
		v_status = '10';
	end if;
    if v_status <> '99' then
        update ostatus set osstatus = v_status,
            osdta = current_date,
            oshora = localtime(0),
            osusua = v_usuario
        where osorcacod = p_orcamento;
	end if;

	Return 1;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_status_orcamento(integer, character) SET search_path=public, pg_temp;

ALTER FUNCTION fn_status_orcamento(integer, character)
  OWNER TO postgres;
