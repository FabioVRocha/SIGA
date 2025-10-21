-- Function: fn_previpg_boleto()

-- DROP FUNCTION fn_previpg_boleto();

CREATE OR REPLACE FUNCTION fn_previpg_boleto()
  RETURNS trigger AS
$BODY$ BEGIN -- Cria registro na PEDBOLETO 
  IF(TG_OP = 'INSERT') THEN
  /* * Caso seja inserido um registro na PREVIPG que tenha a modalidade de cobranca cadastrada para emissao de boletos e o parametro * correspondente esteja 'S', eh criado um registro na tabela PEDBOLETO relativo a essa previsao. */
  IF (
    NEW.PREMODC IN (
      SELECT PEDBOLMCO
      FROM PARAMPA
      WHERE PARAMPACOD = 1
    )
  )
  AND (
    'S' IN (
      SELECT PEDGERBOL
      FROM PARAMPA
      WHERE PARAMPACOD = 1
    )
  ) THEN
INSERT INTO PEDBOLET(
    pebpedido,
    pebtitulo,
    pebseque,
    pebempres,
    pebnnbco,
    pebdtemis,
    pebintegr,
    pebvalor,
    pebdtpedi,
    pebusuari,
    pebmarca,
    pebmardt,
    pebmarhr,
    pebprevdt,
    pebbcobol,
    pebcodlay,
    pebbloqim,
    pebdeposi,
    pebenvema,
    pebdesema,
    pebdtaema,
    peberenvi,
    peberrema,
    pebbenvio,
    pebbarq,
    pebbdtret,
    pebqtdoco
  )
SELECT NEW.PEDIDO,
  (
    CASE
      WHEN NEW.PRENUMERO > 0
      AND NEW.PRENUMERO < 10 THEN (NEW.PEDIDO || '/0' || NEW.PRENUMERO)
      WHEN NEW.PRENUMERO >= 10 THEN (NEW.PEDIDO || '/' || NEW.PRENUMERO)
      ELSE ''
    END
  ),
  NEW.PRENUMERO,
  ped.PEDCLIENTE,
  '',
  '0001-01-01',
  '',
  NEW.PREVALOR,
  ped.PEDDATA,
  '',
  '',
  '0001-01-01',
  '',
  NEW.PREDATA,
  '',
  '',
  'N',
  ped.DEPOSITO,
  '',
  '',
  '0001-01-01',
  '',
  '',
  '0001-01-01',
  '',
  '0001-01-01',
  0
FROM PEDIDO ped
WHERE ped.PEDIDO = NEW.PEDIDO;
END IF;
ELSE IF (TG_OP = 'UPDATE') THEN
/* * Caso a previsao tenha tido a modalidade de cobranca alterada, fazendo com que a modalidade de * cobranca, somente agora, seja a mesma cadastrada para emissao de boletos e o parametro * correspondente esteja 'S', eh criado um registro na tabela PEDBOLETO relativo a essa previsao. * */
IF NEW.PREMODC <> OLD.PREMODC THEN IF (
  NEW.PREMODC IN (
    SELECT PEDBOLMCO
    FROM PARAMPA
    WHERE PARAMPACOD = 1
  )
)
AND (
  'S' IN (
    SELECT PEDGERBOL
    FROM PARAMPA
    WHERE PARAMPACOD = 1
  )
) THEN
INSERT INTO PEDBOLET (
    pebpedido,
    pebtitulo,
    pebseque,
    pebempres,
    pebnnbco,
    pebdtemis,
    pebintegr,
    pebvalor,
    pebdtpedi,
    pebusuari,
    pebmarca,
    pebmardt,
    pebmarhr,
    pebprevdt,
    pebbcobol,
    pebcodlay,
    pebbloqim,
    pebdeposi,
    pebenvema,
    pebdesema,
    pebdtaema,
    peberenvi,
    peberrema,
    pebbenvio,
    pebbarq,
    pebbdtret,
    pebqtdoco
  )
SELECT NEW.PEDIDO,
  (
    CASE
      WHEN NEW.PRENUMERO > 0
      AND NEW.PRENUMERO < 10 THEN (NEW.PEDIDO || '/0' || NEW.PRENUMERO)
      WHEN NEW.PRENUMERO >= 10 THEN (NEW.PEDIDO || '/' || NEW.PRENUMERO)
      ELSE ''
    END
  ),
  NEW.PRENUMERO,
  ped.PEDCLIENTE,
  '',
  '0001-01-01',
  '',
  NEW.PREVALOR,
  ped.PEDDATA,
  '',
  '',
  '0001-01-01',
  '',
  NEW.PREDATA,
  '',
  '',
  'N',
  ped.DEPOSITO,
  '',
  '',
  '0001-01-01',
  '',
  '',
  '0001-01-01',
  '',
  '0001-01-01',
  0
FROM PEDIDO ped
WHERE ped.PEDIDO = NEW.PEDIDO;
ELSE
/* * Caso a previsao tenha tido a modalidade de cobranca alterada mas esta nao esteja cadastrada para emissao de boletos * eventuais registros na PEDBOLETO que referenciam esta previsao serao excluidos, desde que nao tenham tido boleto emitido */
DELETE FROM PEDBOLET
WHERE PEBPEDIDO = NEW.PEDIDO
  AND PEBSEQUE = NEW.PRENUMERO
  AND (
    PEBINTEGR IS NULL
    OR PEBINTEGR = ''
  );
END IF;
ELSE
/* * Caso a previsao tenha sido alterada mas nao tenha ocorrido alteracao na modalidade de cobranca, se houver registro na PEDBOLETO * que faca referencia a essa previsao, o mesmo tera as informacoes de valor e/ou data da previsao atualizadas caso estas tenham * sido alteradas na previsao, desde que nao tenham tido boleto emitido. */
IF NEW.PREVALOR <> OLD.PREVALOR THEN
UPDATE PEDBOLET
SET PEBVALOR = NEW.PREVALOR
WHERE PEBPEDIDO = NEW.PEDIDO
  AND PEBSEQUE = NEW.PRENUMERO
  AND (
    PEBINTEGR IS NULL
    OR PEBINTEGR = ''
  );
END IF;
IF NEW.PREDATA <> OLD.PREDATA THEN
UPDATE PEDBOLET
SET PEBPREVDT = NEW.PREDATA
WHERE PEBPEDIDO = NEW.PEDIDO
  AND PEBSEQUE = NEW.PRENUMERO
  AND (
    PEBINTEGR IS NULL
    OR PEBINTEGR = ''
  );
END IF;
END IF;
ELSE
/* * Caso a previsao tenha sido excluida, eventuais registros na PEDBOLETO que referenciam esta previsao serao excluidos, desde que * nao tenham tido boleto emitido. */
IF (TG_OP = 'DELETE') THEN
DELETE FROM PEDBOLET
WHERE PEBPEDIDO = OLD.PEDIDO
  AND PEBSEQUE = OLD.PRENUMERO
  AND (
    PEBINTEGR IS NULL
    OR PEBINTEGR = ''
  );
END IF;
END IF;
END IF;
RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_previpg_boleto()
  OWNER TO postgres;
