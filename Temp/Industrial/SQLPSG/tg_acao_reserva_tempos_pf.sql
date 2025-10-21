-- Trigger: tg_acao_reserva_tempos_pf on respror

-- DROP TRIGGER tg_acao_reserva_tempos_pf ON respror;

CREATE TRIGGER tg_acao_reserva_tempos_pf
  AFTER INSERT OR UPDATE OR DELETE
  ON respror
  FOR EACH ROW
  EXECUTE PROCEDURE fn_acao_reserva_tempos_pf();
