DROP TRIGGER IF EXISTS tg_titulos_literal_recpag_situacao ON titulos;  

CREATE TRIGGER tg_titulos_literal_recpag_situacao
	BEFORE INSERT OR UPDATE
	ON titulos
	FOR EACH ROW   
	EXECUTE PROCEDURE fn_titulos_literal_recpag_situacao();