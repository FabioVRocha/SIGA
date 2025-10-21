-- Trigger: tg_alterou_respror on ordem

--DROP TRIGGER tg_alterou_respror ON respror;

CREATE TRIGGER tg_alterou_respror
  BEFORE INSERT OR UPDATE
  ON respror
  FOR EACH ROW
  EXECUTE PROCEDURE fn_alterou_respror();