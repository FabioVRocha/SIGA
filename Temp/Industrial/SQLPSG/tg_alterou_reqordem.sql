-- Trigger: tg_alterou_reqordem on reqordem

-- DROP TRIGGER tg_alterou_reqordem ON reqordem;

CREATE TRIGGER tg_alterou_reqordem
  BEFORE INSERT OR UPDATE
  ON reqordem
  FOR EACH ROW
  EXECUTE PROCEDURE fn_alterou_reqordem();