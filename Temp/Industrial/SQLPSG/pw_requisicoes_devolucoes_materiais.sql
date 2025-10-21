-- View: pw_equisicoes_devolucoes_materiais

 --DROP VIEW pw_requisicoes_devolucoes_materiais;

CREATE OR REPLACE VIEW pw_requisicoes_devolucoes_materiais AS 
 SELECT t.itecontrol AS requisicoesdevolucoesmateriais_codigo_controle_pk,
    t.prisequen AS requisicoesdevolucoesmateriais_sequencia_controle_pk,
    t.priproduto AS requisicoesdevolucoesmateriais_produto_codigo_fk,
    CASE
      WHEN t.pritransac = 14 THEN t.priquanti 
      WHEN t.pritransac =  4 THEN t.priquanti * -1
    END AS requisicoesdevolucoesmateriais_qtde_requisicao,  
    t.pridata AS requisicoesdevolucoesmateriais_data_requisicao,
    t.pridocto AS requisicoesdevolucoesmateriais_documento,
    t.priobserv AS requisicoesdevolucoesmateriais_observacao,
    t.pritransac AS requisicoesdevolucoesmateriais_transacao_codigo,
    r.trsnome  AS requisicoesdevolucoesmateriais_transacao_descricao, 
    t.prideposit AS requisicoesdevolucoesmateriais_deposito_codigo_fk       
   FROM toqmovi t
   inner join transa r on r.transacao = t.pritransac
  WHERE t.pritransac = 4::smallint 
  OR t.pritransac = 14::smallint
  ORDER BY t.pritransac DESC;

ALTER TABLE pw_requisicoes_devolucoes_materiais
  OWNER TO postgres;