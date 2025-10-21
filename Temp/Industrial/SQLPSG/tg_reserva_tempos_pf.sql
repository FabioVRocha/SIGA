-- Trigger: tg_reserva_tempos_pf on respror

-- DROP TRIGGER tg_reserva_tempos_pf ON respror;

CREATE TRIGGER tg_reserva_tempos_pf
  AFTER UPDATE OR DELETE
  ON respror
  FOR EACH ROW
  EXECUTE PROCEDURE fn_reserva_tempos_pf();