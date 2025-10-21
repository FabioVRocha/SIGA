-- Trigger: tg_cria_projeto_expedicao on prjexsa

-- DROP TRIGGER tg_cria_projeto_expedicao ON prjexsa;

CREATE TRIGGER tg_cria_projeto_expedicao
  BEFORE INSERT
  ON prjexsa
  FOR EACH ROW
  EXECUTE PROCEDURE fn_cria_projeto_expedicao();
