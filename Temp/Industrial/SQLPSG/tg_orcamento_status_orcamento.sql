-- Trigger: tg_orcamento_status_orcamento on orcament

-- DROP TRIGGER tg_orcamento_status_orcamento ON orcament;

CREATE TRIGGER tg_orcamento_status_orcamento
  BEFORE INSERT OR UPDATE OR DELETE
  ON orcament
  FOR EACH ROW
  EXECUTE PROCEDURE fn_orcamento_status_orcamento();
