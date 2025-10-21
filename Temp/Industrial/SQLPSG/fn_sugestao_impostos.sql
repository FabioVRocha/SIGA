CREATE OR REPLACE FUNCTION fn_sugestao_impostos(
        pdeposito numeric,
        pgrupo numeric,
        psubgr numeric,
        pestado character,
        poperacao character,
        pclascod character,
        pregime character,
        pcontrib character
    ) RETURNS TEXT AS $$
DECLARE resultado text;
BEGIN WITH registro_bobo AS (
    --Registro bobo com codigo 1 para ter o registro base para o join das outras buscas
    SELECT 1 AS codigo
),
suimpos_filtrada_e_ordenada AS (
    SELECT *
    FROM suimpos --Filtros que são recebidos no procedimento de sugestão de impostos
    WHERE (
            SUIDEPOSIT = pdeposito
            or (nullif(SUIDEPOSIT, 0)) is NULL
        )
        and (
            SUIGRUPO = pgrupo
            or (nullif(SUIGRUPO, 0)) is NULL
        )
        and (
            SUISUBGRUP = psubgr
            or (nullif(SUISUBGRUP, 0)) is NULL
        )
        and (
            SUIESTADO = pestado
            or (nullif(trim(SUIESTADO), '')) is NULL
        )
        and (
            SUIOPERACA = poperacao
            or (nullif(trim(SUIOPERACA), '')) is NULL
        )
        and (
            SUICLASCOD = pclascod
            or (NULLif(trim(SUICLASCOD), '')) is NULL
        )
        and (
            SUIREGIME = pregime
            or (nullif(trim(SUIREGIME), '')) is NULL
        )
        and (
            SUICONTRIB = pcontrib
            or (nullif(trim(SUICONTRIB), '')) is NULL
        )
    ORDER BY suiordem ASC
),
icms_inf AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_icms,
        /*ICMS*/
        SUIBASICMS,
        SUIALQICMS,
        SUIBASESUB,
        SUIALQSUBT,
        SUIREDMVA,
        SUIMVASUB,
        SUICARMED       
    FROM suimpos_filtrada_e_ordenada
    WHERE true
    LIMIT 1
), ipi_inf AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_ipi,       
        SUIBASIPI,
        SUIALQIPI
    FROM suimpos_filtrada_e_ordenada
    WHERE true
    LIMIT 1
), cst_de_icms AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_csticms,
        suitribuco
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND nullif(trim(suitribuco), '') is NOT NULL
    LIMIT 1
), cst_de_ipi AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_cstipi,
        SUITRIIPI
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(trim(SUITRIIPI), '')) is NOT NULL
    LIMIT 1
), observacao AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_observacao,
        SUIOBSERVA
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(SUIOBSERVA, 0)) is NOT NULL
    LIMIT 1
), diferenca_icms AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_diferencaicms,
        suialqdifi,
        suibasdifi
    FROM suimpos_filtrada_e_ordenada
    WHERE TRUE --true 
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(suialqdifi, 0)) is NOT NULL
    LIMIT 1
), cst_de_pis AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_cstpis,
        SUITRIPIS
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(trim(SUITRIPIS), '')) is NOT NULL
    LIMIT 1	
), cst_de_cofins AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_cstcofins,
        SUITRICOF
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(trim(SUITRICOF), '')) is NOT NULL
    LIMIT 1		
), cst_de_issqn AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_cstissqn,
        SUITRISSQN
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(trim(SUITRISSQN), '')) is NOT NULL
    LIMIT 1		
), aliquotas_de_piscofins AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_aliquotaspiscofins,
        SUIALPIS,
        SUIALCOF,
        suibcpisco
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (
            SUIALPIS > 0
            or SUIALCOF > 0
            or suibcpisco > 0
        )
    LIMIT 1
), cst_de_st_pis AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_cstdestpis,
        suisttripi
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(trim(suisttripi), '')) is NOT NULL
    LIMIT 1
), cst_de_st_cofins AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_cstdestcofins,
        suisttrico
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(trim(suisttrico), '')) is NOT NULL
    LIMIT 1
), aliquota_de_st_de_piscofins AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_aliquotadestpiscofins,
        SUISTPISAL,
        SUISTCOFAL,
        suistbpisc
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (
            SUISTPISAL > 0
            OR SUISTCOFAL > 0
            OR suistbpisc > 0
        )
    LIMIT 1
), enquadramento_ipi AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_enquadramentoipi,
        SUIENQIPI
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND (nullif(trim(SUIENQIPI), '')) is NOT NULL
    LIMIT 1
), icms_antecipado AS (
    SELECT 1 AS codigo,
        suiordem AS ordem_icmsantecipado,
        suialqanti
    FROM suimpos_filtrada_e_ordenada
    WHERE true
        /*condicao adicional para considerar que a informacao esta alimentada neste nivel*/
        AND suialqanti > 0
    LIMIT 1
), resultado_final as(
    SELECT  coalesce(icms_inf.codigo::text, '') as icmsinfCODIGO,
            coalesce(icms_inf.ordem_icms::text, '') as icmsinfORDEMICMSINF,
            coalesce(icms_inf.SUIBASICMS::Text, '') as icmsinfSUIBASICMS,
            coalesce(icms_inf.SUIALQICMS::Text, '') as icmsinfSUIALQICMS,
            coalesce(icms_inf.SUIBASESUB::Text, '') as icmsinfSUIBASESUB,
            coalesce(icms_inf.SUIALQSUBT::text, '') as icmsinfSUIALQSUBT,
            coalesce(icms_inf.SUIREDMVA::Text, '') as icmsinfSUIREDMVA,
            coalesce(icms_inf.SUIMVASUB::Text, '') as icmsinfSUIMVASUB,
            coalesce(icms_inf.SUICARMED::Text, '') as icmsinfSUICARMED,
			
			coalesce(ipi_inf.codigo::text, '') as ipiinfCODIGO,
            coalesce(ipi_inf.ordem_ipi::text, '') as ipiinfORDEMIPIINF,
            coalesce(ipi_inf.SUIBASIPI::Text, '') as ipiinfSUIBASIPI,
            coalesce(ipi_inf.SUIALQIPI::Text, '') as ipiinfSUIALQIPI,
			
            coalesce(cst_de_icms.codigo::text, '') as cstdeicmsCODIGO,
            coalesce(cst_de_icms.ordem_csticms::Text, '') as cstdeicmsORDEMCSTICMS,
            coalesce(cst_de_icms.suitribuco::text, '') as cstdeicmsSUITRIBUCO,
			
            coalesce(cst_de_ipi.codigo::text, '') as cstdeipiCODIGO,
            coalesce(cst_de_ipi.ordem_cstipi::text, '') as cstdeipiORDEMCSTIPI,
            coalesce(cst_de_ipi.SUITRIIPI::text, '') as cstdeipiSUITRIIPI,
            coalesce(observacao.codigo::text, '') as observacaoCODIGO,
            coalesce(observacao.ordem_observacao::text, '') as observacaoORDEMOBSERVACAO,
            coalesce(observacao.SUIOBSERVA::text, '') as observacaoSUIOBSERVA,
            coalesce(diferenca_icms.codigo::text, '') as diferencaicmsCODIGO,
            coalesce(diferenca_icms.ordem_diferencaicms::text, '') as diferencaicmsORDEMDIFERENCAICMS,
            coalesce(diferenca_icms.suialqdifi::text, '') as diferencaicmsSUIALQDIFI,
            coalesce(diferenca_icms.suibasdifi::text, '') as diferencaicmsSUIBASDIFI,
            coalesce(cst_de_pis.codigo::text, '') as cstdepisCODIGO,
            coalesce(cst_de_pis.ordem_cstpis::text, '') as cstdepisORDEMCSTPIS,
            coalesce(cst_de_pis.SUITRIPIS::text, '') as cstdepisSUITRIPIS,			
            coalesce(cst_de_cofins.codigo::text, '') as cstdecofinsCODIGO,
            coalesce(cst_de_cofins.ordem_cstcofins::text, '') as cstdecofinsORDEMCSTCOFINS,
            coalesce(cst_de_cofins.SUITRICOF::text, '') as cstdecofinsSUITRICOF,
            coalesce(cst_de_issqn.codigo::text, '') as cstdeissqnCODIGO,
            coalesce(cst_de_issqn.ordem_cstissqn::text, '') as cstdeissqnORDEMCSTISSQN,		
            coalesce(cst_de_issqn.SUITRISSQN::text, '') as cstdeissqnSUITRISSQN,			
            coalesce(aliquotas_de_piscofins.codigo::text, '') as aliquotasdepiscofinsCODIGO,
            coalesce(aliquotas_de_piscofins.ordem_aliquotaspiscofins::text,'') as aliquotasdepiscofinsORDEMALIQUOTASPISCOFINS,
            coalesce(aliquotas_de_piscofins.SUIALPIS::text, '') as aliquotasdepiscofinsSUIALPIS,
            coalesce(aliquotas_de_piscofins.SUIALCOF::text, '') as aliquotasdepiscofinsSUIALCOF,
            coalesce(aliquotas_de_piscofins.suibcpisco::text, '') as aliquotasdepiscofinsSUIBCPISCO,
            coalesce(cst_de_st_pis.codigo::text, '') as cstdestpisCODIGO,
            coalesce(cst_de_st_pis.ordem_cstdestpis::text, '') as cstdestpisORDEMCSTDESTPIS,
            coalesce(cst_de_st_pis.suisttripi::text, '') as cstdestpisSUISTTRIPI,
            coalesce(cst_de_st_cofins.codigo::text, '') as cstdestcofinsCODIGO,
            coalesce(cst_de_st_cofins.ordem_cstdestcofins::text, '') as cstdestcofinsORDEMCSTDESTCOFINS,
            coalesce(cst_de_st_cofins.suisttrico::text, '') as cstdestcofinsSUISTTRICO,
            coalesce(aliquota_de_st_de_piscofins.codigo::text, '') as aliquotadestdepiscofinsCODIGO,
            coalesce(aliquota_de_st_de_piscofins.ordem_aliquotadestpiscofins::text,'') as aliquotadestdepiscofinsORDEMALIQUOTADESTPISCOFINS,
            coalesce(aliquota_de_st_de_piscofins.SUISTPISAL::text, '') as aliquotadestdepiscofinsSUISTPISAL, 
            coalesce(aliquota_de_st_de_piscofins.SUISTCOFAL::text, '') as aliquotadestdepiscofinsSUISTCOFAL,
            coalesce(aliquota_de_st_de_piscofins.suistbpisc::text, '') as aliquotadestdepiscofinsSUISTBPISC,
            coalesce(enquadramento_ipi.codigo::text, '') as enquadramentoipiCODIGO,
            coalesce(enquadramento_ipi.ordem_enquadramentoipi::text,'') as enquadramentoipiORDEMENQUADRAMENTOIPI,
            coalesce(enquadramento_ipi.SUIENQIPI::text, '') as enquadramentoipiSUIENQIPI,
            coalesce(icms_antecipado.codigo::text, '') as icmsantecipadoCODIGO,
            coalesce(icms_antecipado.ordem_icmsantecipado::text, '') as icmsantecipadoORDEMICMSANTECIPADO,
            coalesce(icms_antecipado.suialqanti::text, '') as icmsantecipadoSUIALQANTI
    FROM registro_bobo r
        left join icms_inf on (icms_inf.codigo = r.codigo)		
        left join ipi_inf on (ipi_inf.codigo = r.codigo)
        left join cst_de_icms on (cst_de_icms.codigo = r.codigo)
        left join cst_de_ipi on (cst_de_ipi.codigo = r.codigo)
        left join observacao on (observacao.codigo = r.codigo)
        left join diferenca_icms on (diferenca_icms.codigo = r.codigo)
        left join cst_de_pis    on (cst_de_pis.codigo    = r.codigo)
        left join cst_de_cofins on (cst_de_cofins.codigo = r.codigo)
		left join cst_de_issqn  on (cst_de_issqn.codigo  = r.codigo)
        left join aliquotas_de_piscofins on (aliquotas_de_piscofins.codigo = r.codigo)
        left join cst_de_st_pis on (cst_de_st_pis.codigo = r.codigo)
        left join cst_de_st_cofins on (cst_de_st_cofins.codigo = r.codigo)
        left join aliquota_de_st_de_piscofins on (aliquota_de_st_de_piscofins.codigo = r.codigo)
        left join enquadramento_ipi on (enquadramento_ipi.codigo = r.codigo)
        left join icms_antecipado on (icms_antecipado.codigo = r.codigo)
)
select to_json(resultado_final) into resultado
from resultado_final
limit 1;
return resultado;
END;
$$ LANGUAGE plpgsql VOLATILE COST 100;
ALTER FUNCTION fn_sugestao_impostos(
    numeric,
    numeric,
    numeric,
    character,
    character,
    character,
    character,
    character
)
SET search_path = public,
    pg_temp;
ALTER FUNCTION fn_sugestao_impostos(
    numeric,
    numeric,
    numeric,
    character,
    character,
    character,
    character,
    character
) OWNER TO postgres;

