-- Trigger: tg_alterou_processo on processo

-- DROP TRIGGER tg_alterou_processo ON processo;

CREATE TRIGGER tg_alterou_processo
  BEFORE INSERT OR UPDATE
  ON processo
  FOR EACH ROW
  EXECUTE PROCEDURE fn_alterou_processo();