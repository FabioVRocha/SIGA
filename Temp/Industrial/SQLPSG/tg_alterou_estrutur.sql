create trigger tg_alterou_estrutur
  BEFORE INSERT OR UPDATE
  ON estrutur
  FOR EACH ROW execute procedure fn_alterou_estrutur();