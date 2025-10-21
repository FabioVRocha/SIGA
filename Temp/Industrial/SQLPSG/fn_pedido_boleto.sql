CREATE OR REPLACE FUNCTION fn_pedido_boleto()
    RETURNS trigger AS
$BODY$
	BEGIN							
        IF (TG_OP = 'UPDATE') THEN
            /*
            *  Caso o pedido tenha o cliente e/ou a data atualizados, eventuais registros da PEDBOLETO que referenciem este pedido serao
            *  alterados, desde que nao tenham tido boleto emitido.
            */
            IF NEW.PEDCLIENTE <> OLD.PEDCLIENTE THEN
                UPDATE PEDBOLET SET PEBEMPRES = NEW.PEDCLIENTE WHERE PEBPEDIDO = NEW.PEDIDO AND (PEBINTEGR IS NULL OR PEBINTEGR = '');
            END IF;      

            IF NEW.PEDDATA <> OLD.PEDDATA THEN
                UPDATE PEDBOLET SET PEBDTPEDI = NEW.PEDDATA WHERE PEBPEDIDO = NEW.PEDIDO AND (PEBINTEGR IS NULL OR PEBINTEGR = '');
            END IF;

            IF NEW.DEPOSITO <> OLD.DEPOSITO THEN
                UPDATE PEDBOLET SET PEBDEPOSI = NEW.DEPOSITO WHERE PEBPEDIDO = NEW.PEDIDO AND (PEBINTEGR IS NULL OR PEBINTEGR = '');
            END IF;
        END IF;
		RETURN NEW;
	END;
$BODY$
	LANGUAGE plpgsql
	COST 100;