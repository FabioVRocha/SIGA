-- Trigger: tg_tipo_vendedor_comiped on comiped

-- DROP TRIGGER tg_tipo_vendedor_comiped ON comiped;

CREATE TRIGGER tg_tipo_vendedor_comiped
  BEFORE INSERT OR UPDATE
  ON comiped
  FOR EACH ROW
  EXECUTE PROCEDURE fn_tipo_rep();