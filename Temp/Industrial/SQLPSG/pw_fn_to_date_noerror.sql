CREATE OR REPLACE FUNCTION to_date_noerror(s text, fmt text)
  RETURNS date AS
$$
BEGIN
    return to_date(s, fmt);
EXCEPTION
    WHEN others THEN return null;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION to_date_noerror(s text, fmt text) IS 'Converte string em date formatado e retorna null caso haja erro.';

ALTER FUNCTION to_date_noerror(text, text)
  OWNER TO postgres;