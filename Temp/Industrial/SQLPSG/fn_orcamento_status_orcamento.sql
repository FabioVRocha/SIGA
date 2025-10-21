-- Function: fn_orcamento_status_orcamento()

-- DROP FUNCTION fn_orcamento_status_orcamento();

CREATE OR REPLACE FUNCTION fn_orcamento_status_orcamento()
  RETURNS trigger AS
$BODY$
declare
	v_orcamento integer;
	v_integer integer;
	v_ip character(20);
	v_porta integer;
	v_usuario character(10);
	v_status character(1);	
BEGIN

	If (TG_OP = 'INSERT') or (TG_OP = 'UPDATE') then
		v_orcamento = new.orcacod;
		v_status = new.orcastatus;
	Else
		v_orcamento = old.orcacod;
		v_status = old.orcastatus;
	End if;

	v_integer = (select fn_status_orcamento(v_orcamento, v_status));

	If (TG_OP = 'INSERT') or (TG_OP = 'UPDATE') then
		--Grava data, hora e usuario na tabela. Busca o Usuario Logado no sistema, pela informacao do IP e Porta gravados na Userid
		v_ip = (select inet_client_addr());
		v_porta = (select inet_client_port());
		v_usuario = (select uiusuario
		              from userid
		             where uidip = v_ip
		               and uidport = v_porta
		               and uidlocal = 1 limit 1);
	
		new.orcaltdta = current_date;
		new.orcalthra = localtime(0);
		new.orcaltusu = v_usuario;
		return new;
	else
		Return old;
	end if;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_orcamento_status_orcamento() SET search_path=public, pg_temp;

ALTER FUNCTION fn_orcamento_status_orcamento()
  OWNER TO postgres;
