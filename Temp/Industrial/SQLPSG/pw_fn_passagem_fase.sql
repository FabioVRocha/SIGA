-- Function: pw_fn_passagem_fase(numeric)

-- DROP FUNCTION pw_fn_passagem_fase(numeric);

CREATE OR REPLACE FUNCTION pw_fn_passagem_fase(IN p_ordem numeric)
  RETURNS json  
AS $BODY$
DECLARE
    resultado_json json;
begin
	SELECT json_agg(row_to_json(t)) INTO resultado_json
    FROM (
        SELECT 
            pasfase.ordem::integer AS pasfase_ordem,
            pasfase.fase::smallint AS pasfase_fase,
            max(pasfase.pasdata)::date AS pasfase_data_passagem,
            sum(pasquanti)::text AS pasfase_quantidade_passagem
        FROM pasfase 
        WHERE pasfase.ordem = p_ordem
        GROUP BY pasfase.ordem, pasfase.fase
        ORDER BY pasfase.ordem, pasfase.fase
    ) t;

    RETURN resultado_json;
end;
$BODY$
  LANGUAGE plpgsql ;  
ALTER FUNCTION pw_fn_passagem_fase(numeric) SET search_path=public, pg_temp;

ALTER FUNCTION pw_fn_passagem_fase(numeric)
  OWNER TO postgres;
