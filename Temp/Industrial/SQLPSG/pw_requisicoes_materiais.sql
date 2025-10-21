-- View: pw_requisicoes_materiais

 --DROP VIEW pw_requisicoes_materiais;

CREATE OR REPLACE VIEW pw_requisicoes_materiais AS 
 SELECT t.itecontrol AS requisicoesmateriais_codigo_controle_pk,
    t.prisequen AS requisicoesmateriais_sequencia_controle_pk,
    t.priproduto AS requisicoesmateriais_produto_codigo_fk,
    t.priquanti AS requisicoesmateriais_qtde_requisicao,
    t.pridata AS requisicoesmateriais_data_requisicao,
    t.pridocto AS requisicoesmateriais_documento,
    t.priobserv AS requisicoesmateriais_observacao,
    t.pritransac AS requisicoesmateriais_transacao_codigo,
    r.trsnome  AS requisicoesmateriais_transacao_descricao, 
    t.prideposit AS requisicoesmateriais_deposito_codigo_fk       
   FROM toqmovi t
   inner join transa r on r.transacao = t.pritransac
  WHERE t.pritransac = 14::smallint
  ORDER BY t.pritransac DESC;

ALTER TABLE pw_requisicoes_materiais
  OWNER TO postgres;
