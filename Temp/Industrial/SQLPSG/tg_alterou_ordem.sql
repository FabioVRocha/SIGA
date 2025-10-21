-- Trigger: tg_alterou_ordem on ordem

-- DROP TRIGGER tg_alterou_ordem ON ordem;

CREATE TRIGGER tg_alterou_ordem
  BEFORE INSERT OR UPDATE
  ON ordem
  FOR EACH ROW
  EXECUTE PROCEDURE fn_alterou_ordem();