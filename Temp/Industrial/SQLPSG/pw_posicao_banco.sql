-- View: pw_posicao_banco
-- DROP VIEW pw_posicao_banco;
CREATE OR REPLACE VIEW pw_posicao_banco AS
SELECT BCO.BANCO as posicao_banco_codigo,
    BCO.BANNOME as posicao_banco_nome,
    PBADEPOSIT as posicao_banco_deposito,
    PBDATA as posicao_banco_data,
    PBSALDO as posicao_banco_valor_saldo
FROM PBANCO AS PBCO
    LEFT JOIN BANCO AS BCO ON BCO.BANCO = PBCO.BANCO
ORDER BY PBDATA DESC;
ALTER TABLE pw_posicao_banco OWNER TO postgres;