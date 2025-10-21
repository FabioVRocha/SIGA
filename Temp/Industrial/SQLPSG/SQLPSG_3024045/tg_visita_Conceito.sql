-- Trigger: tg_visita_conceito on visita

-- DROP TRIGGER tg_visita_conceito ON visita;

CREATE TRIGGER tg_visita_conceito
  BEFORE INSERT OR UPDATE
  ON visita
  FOR EACH ROW
  EXECUTE PROCEDURE fn_visita_conceito();
