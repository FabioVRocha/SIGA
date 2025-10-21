-- View: pw_posicao_banco_conciliado
-- DROP VIEW pw_posicao_banco_conciliado;
CREATE OR REPLACE VIEW pw_posicao_banco_conciliado AS
SELECT PSCBANCO as posicao_banco_conciliado_codigo,
    BANNOME as posicao_banco_conciliado_nome,
    PSCDEPOSIT as posicao_banco_conciliado_deposito,
    PSCDATA as posicao_banco_conciliado_data,
    PSCSALDO as posicao_banco_conciliado_valor_saldo
FROM PBANCON AS PBAN
    LEFT JOIN BANCO AS BCO ON BCO.BANCO = PBAN.PSCBANCO
ORDER BY PSCDATA DESC;
ALTER TABLE pw_posicao_banco_conciliado OWNER TO postgres;