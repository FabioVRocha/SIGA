-- Function: fn_merl13(character varying, character)

-- DROP FUNCTION fn_merl13(character varying, character);

CREATE OR REPLACE FUNCTION fn_merl13(json_data character varying, codigo_id_orcamento_mlb character)
  RETURNS void AS
$BODY$
DECLARE
    sigla CHAR(2);
BEGIN
    -- Atualização dos dados na tabela
    UPDATE mrkp01
    SET 
        --site_id = (json_data::json->>'site_id')::CHARACTER VARYING,
        --cust_id = (json_data::json->'buyer'->>'cust_id')::CHARACTER VARYING,
        mrknompes = (json_data::json->'buyer'->'billing_info'->>'name')::CHARACTER varying || ' ' || (json_data::json->'buyer'->'billing_info'->>'last_name')::CHARACTER VARYING,
        --identification_type = (json_data::json->'buyer'->'billing_info'->'identification'->>'type')::CHARACTER VARYING,
        mrkcpfcnp = (json_data::json->'buyer'->'billing_info'->'identification'->>'number')::CHARACTER VARYING,
        mrkendere = (json_data::json->'buyer'->'billing_info'->'address'->>'street_name')::CHARACTER varying || ' ' || (json_data::json->'buyer'->'billing_info'->'address'->>'street_number')::CHARACTER VARYING,
        mrknocida = (json_data::json->'buyer'->'billing_info'->'address'->>'city_name')::CHARACTER VARYING,
        mrkestado = CASE lower((json_data::json->'buyer'->'billing_info'->'address'->'state'->>'name')::CHARACTER varying)
                    WHEN 'acre' THEN 'AC'
                    WHEN 'alagoas' THEN 'AL'
                    WHEN 'amapá' THEN 'AP'
                    WHEN 'amazonas' THEN 'AM'
                    WHEN 'bahia' THEN 'BA'
                    WHEN 'ceará' THEN 'CE'
                    WHEN 'distrito federal' THEN 'DF'
                    WHEN 'espírito santo' THEN 'ES'
                    WHEN 'goiás' THEN 'GO'
                    WHEN 'maranhão' THEN 'MA'
                    WHEN 'mato grosso' THEN 'MT'
                    WHEN 'mato grosso do sul' THEN 'MS'
                    WHEN 'minas gerais' THEN 'MG'
                    WHEN 'pará' THEN 'PA'
                    WHEN 'paraíba' THEN 'PB'
                    WHEN 'paraná' THEN 'PR'
                    WHEN 'pernambuco' THEN 'PE'
                    WHEN 'piauí' THEN 'PI'
                    WHEN 'rio de janeiro' THEN 'RJ'
                    WHEN 'rio grande do norte' THEN 'RN'
                    WHEN 'rio grande do sul' THEN 'RS'
                    WHEN 'rondônia' THEN 'RO'
                    WHEN 'roraima' THEN 'RR'
                    WHEN 'santa catarina' THEN 'SC'
                    WHEN 'são paulo' THEN 'SP'
                    WHEN 'sergipe' THEN 'SE'
                    WHEN 'tocantins' THEN 'TO'
                    ELSE NULL
                END,
        mrkcep = (json_data::json->'buyer'->'billing_info'->'address'->>'zip_code')::CHARACTER VARYING,
        mrkbairro =  (json_data::json->'buyer'->'billing_info'->'address'->>'neighborhood')::CHARACTER varying,
        mrkinscest = (json_data::json->'buyer'->'billing_info'->'taxes'->'inscriptions'->>'state_registration')::CHARACTER varying,
        mrkcontrib = (json_data::json->'buyer'->'billing_info'->'taxes'->'taxpayer_type'->>'description')::CHARACTER varying
        --country_id = (json_data::json->'buyer'->'billing_info'->'address'->>'country_id')::CHARACTER VARYING,
        --normalized = ((json_data::json->'buyer'->'billing_info'->'attributes'->>'normalized')::BOOLEAN),
        --cust_type = (json_data::json->'buyer'->'billing_info'->'attributes'->>'cust_type')::CHARACTER VARYING;
   WHERE mrkidorca = codigo_id_orcamento_mlb;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_merl13(character varying, character)
  OWNER TO postgres;
