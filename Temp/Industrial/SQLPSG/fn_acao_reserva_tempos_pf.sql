-- Function: fn_acao_reserva_tempos_pf()

-- DROP FUNCTION fn_acao_reserva_tempos_pf();

CREATE OR REPLACE FUNCTION fn_acao_reserva_tempos_pf()
  RETURNS trigger AS
$BODY$
DECLARE
    v_rdcolpf TEXT;  -- Variável para armazenar o valor de rdcolpf
BEGIN
    -- Armazena o valor de rdcolpf antes de entrar na logica
    SELECT rdcolpf INTO v_rdcolpf FROM notparam WHERE notparam = 1 LIMIT 1;

    -- Se o parametro for K, realiza a atualizacao na tabela ordens
    IF v_rdcolpf = 'K' THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE ordens 
            SET acao = 1 
            WHERE ordem = NEW.rprordem::char(10) 
              AND sequencia = NEW.rprproce::char(10);
            RETURN NEW;

        ELSIF TG_OP = 'UPDATE' THEN
            UPDATE ordens 
            SET acao = 2 
            WHERE ordem = NEW.rprordem::char(10) 
              AND sequencia = NEW.rprproce::char(10);
            RETURN NEW;

        ELSIF TG_OP = 'DELETE' THEN
            UPDATE ordens 
            SET acao = 3 
            WHERE ordem = OLD.rprordem::char(10) 
              AND sequencia = OLD.rprproce::char(10);
            RETURN OLD;
        END IF;
    END IF;

    -- Retorna os valores conforme o tipo da operacao
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NULL;  -- Retorno de seguranca
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_acao_reserva_tempos_pf() SET search_path=public, pg_temp;

ALTER FUNCTION fn_acao_reserva_tempos_pf()
  OWNER TO postgres;
