CREATE OR REPLACE FUNCTION pw_fn_data_diferenca_dias_psg(p_data_fim date, p_data_inicio date)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
BEGIN
return p_data_fim - p_data_inicio;
END;
$function$;

COMMENT ON FUNCTION pw_fn_data_diferenca_dias_psg(p_data_fim date, p_data_inicio date) IS 'Retorna a diferença de dias entre duas datas.';

ALTER FUNCTION pw_fn_data_diferenca_dias_psg(date, date)
  OWNER TO postgres;