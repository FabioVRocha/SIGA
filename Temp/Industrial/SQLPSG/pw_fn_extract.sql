-- Function: pw_fn_extract(text, timestamp without time zone)

--DROP FUNCTION pw_fn_extract(text, timestamp without time zone);

CREATE OR REPLACE FUNCTION pw_fn_extract(p_campo text, p_data timestamp without time zone)
  RETURNS text AS
$BODY$
DECLARE
  result text;
BEGIN
  CASE LOWER(p_campo)
    WHEN 'year' THEN result := EXTRACT(YEAR FROM p_data);
    WHEN 'month' THEN result := EXTRACT(MONTH FROM p_data);
    WHEN 'day' THEN result :=  EXTRACT(DAY FROM p_data);
    WHEN 'hour' THEN result :=  EXTRACT(HOUR FROM p_data);
    WHEN 'minute' THEN result :=  EXTRACT(MINUTE FROM p_data);
    WHEN 'second' THEN result :=  EXTRACT(SECOND FROM p_data);
    WHEN 'millisecond' THEN result := EXTRACT(MILLISECOND FROM p_data);
    WHEN 'microsecond' THEN result := EXTRACT(MICROSECOND FROM p_data);
    WHEN 'quarter' THEN result := EXTRACT(QUARTER FROM p_data);
    WHEN 'week' THEN result := EXTRACT(WEEK FROM p_data);
    WHEN 'dow' THEN result := EXTRACT(DOW FROM p_data);
    WHEN 'doy' THEN result := EXTRACT(DOY FROM p_data);
    WHEN 'epoch' THEN result := EXTRACT(EPOCH FROM p_data);
    ELSE
      RAISE EXCEPTION 'Opcao invalida na funcao pw_fn_extract: %', p_campo;
  END CASE;
  RETURN result;
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

COMMENT ON FUNCTION pw_fn_extract(text, timestamp without time zone) IS 'A fun��o EXTRACT � usada para "pegar" uma parte espec�fica de uma data ou hora.
Por exemplo, data "2023-10-09", com a fun��o EXTRACT, voc� pode escolher extrair apenas o ano (2023), o m�s (10) ou o dia (9) dessa data.

 - p_campo: escolher como ficar� a informa��o extra�da, com as op��es v�lidas:
      - "year": Ano da data.
      - "month": M�s da data.
      - "day": Dia do m�s.
      - "hour": Hora.
      - "minute": Minuto.
      - "second": Segundo.
      - "millisecond": Milissegundo.
      - "microsecond": Microssegundo.
      - "quarter": Trimestre do ano.
      - "week": Semana do ano.
      - "dow": Dia da semana (0=domingo, 1=segunda-feira, etc.).
      - "doy": Dia do ano.
      - "epoch": Segundos desde a �poca (epoch).

  - p_data: informar qual o componente ser� extra�do.';

ALTER FUNCTION pw_fn_extract(text, timestamp without time zone)
  OWNER TO postgres;