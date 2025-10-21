-- Trigger: tg_tipocontato_status on tipcont

-- DROP TRIGGER tg_tipocontato_status ON tipcont;

CREATE TRIGGER tg_tipocontato_status
  BEFORE INSERT OR UPDATE
  ON tipcont
  FOR EACH ROW
  EXECUTE PROCEDURE fn_tipocontato_status();