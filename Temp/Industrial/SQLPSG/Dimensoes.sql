 -- ### pw_dia ###
DROP VIEW IF EXISTS pw_dia;
 
CREATE OR REPLACE VIEW pw_dia AS 
 SELECT lpad(generate_series(1, 31)::character varying::text, 2, '0'::text) AS dia_codigo_pk,
    lpad(generate_series(1, 31)::character varying::text, 2, '0'::text) AS dia_descricao;

	
 -- ### pw_semana ###
DROP VIEW IF EXISTS pw_semana;
 
CREATE OR REPLACE VIEW pw_semana AS 
 SELECT lpad(generate_series(1, 53)::character varying::text, 2, '0'::text) AS semana_codigo_pk,
    lpad(generate_series(1, 53)::character varying::text, 2, '0'::text) AS semana_descricao;
	
	
-- ### pw_quinzena ###	
DROP VIEW IF EXISTS pw_quinzena;

CREATE OR REPLACE VIEW pw_quinzena AS 
 SELECT lpad(generate_series(1, 2)::character varying::text, 2, '0'::text) AS quinzena_codigo_pk,
    lpad(generate_series(1, 2)::character varying::text, 2, '0'::text) AS quinzena_descricao;	
	
	
-- ### pw_mes ###
DROP VIEW IF EXISTS pw_mes;

CREATE OR REPLACE VIEW pw_mes AS 
 SELECT lpad(generate_series(1, 12)::character varying::text, 2, '0'::text) AS mes_codigo_pk,
    lpad(generate_series(1, 12)::character varying::text, 2, '0'::text) AS mes_descricao;	

	
-- ### pw_ano ###
DROP VIEW IF EXISTS pw_ano;

CREATE OR REPLACE VIEW pw_ano AS 
 SELECT lpad(generate_series(1995, 2050)::character varying::text, 4, '0'::text) AS ano_codigo_pk,
    lpad(generate_series(1995, 2050)::character varying::text, 4, '0'::text) AS ano_descricao;
	
	
-- ### pw_anomes ###
DROP VIEW IF EXISTS pw_anomes;

CREATE OR REPLACE VIEW pw_anomes AS 
 SELECT to_char(generate_series('2018-01-01'::date - '10 years'::interval, '2018-06-01'::date + '2 years'::interval, '1 mon'::interval), 'YYYYMM'::text) AS anomes_codigo_pk,
    to_char(generate_series('2018-01-01'::date - '10 years'::interval, '2018-06-01'::date + '2 years'::interval, '1 mon'::interval), 'YYYYMM'::text) AS anomes_descricao;

	
-- ### pw_bimestre ###
DROP VIEW IF EXISTS pw_bimestre;

CREATE OR REPLACE VIEW pw_bimestre AS 
 SELECT lpad(generate_series(1, 6)::character varying::text, 2, '0'::text) AS bimestre_codigo_pk,
    lpad(generate_series(1, 6)::character varying::text, 2, '0'::text) AS bimestre_descricao;	
	
	
-- ### pw_trimestre ###	
DROP VIEW IF EXISTS pw_trimestre;

CREATE OR REPLACE VIEW pw_trimestre AS 
 SELECT lpad(generate_series(1, 4)::character varying::text, 2, '0'::text) AS trimestre_codigo_pk,
    lpad(generate_series(1, 4)::character varying::text, 2, '0'::text) AS trimestre_descricao;	

	
-- ### pw_semestre ###	
DROP VIEW IF EXISTS pw_semestre;

CREATE OR REPLACE VIEW pw_semestre AS 
 SELECT lpad(generate_series(1, 2)::character varying::text, 2, '0'::text) AS semestre_codigo_pk,
    lpad(generate_series(1, 2)::character varying::text, 2, '0'::text) AS semestre_descricao;	
	
	
-- ### pw_cfop ###	
DROP VIEW IF EXISTS pw_cfop;

CREATE OR REPLACE VIEW pw_cfop AS 
 SELECT opera.operacao AS cfop_codigo_pk,
    opera.opedescri AS cfop_descricao,
    opera.opetransac AS cfop_transacao_codigo_fk,
    opera.opeopofi AS cfop_oficial_codigo,
	CASE
            WHEN substring(opera.opeopofi, 1, 1) in ('3', '7')  THEN 'Mercado Externo'::text
            ELSE 'Mercado Interno'::text
    END AS cfop_tipo_mercado
   FROM opera
  ORDER BY opera.operacao;	
  
  
-- ### pw_cidade ###  
DROP VIEW IF EXISTS pw_cidade;

CREATE OR REPLACE VIEW pw_cidade AS 
 SELECT c.cidade AS cidade_codigo_pk,
    c.cidnome AS cidade_descricao,
    c.estado AS cidade_estado_codigo_fk
   FROM cidade c
  ORDER BY c.cidnome;
  

-- ### pw_estado ###  
DROP VIEW IF EXISTS pw_estado;

CREATE OR REPLACE VIEW pw_estado AS 
 SELECT e.estado AS estado_codigo_pk,
    e.estnome AS estado_descricao,
    e.pais AS estado_pais_codigo_fk
   FROM estado e
  ORDER BY e.estnome;  
  
  
-- ### pw_pais ###  
DROP VIEW IF EXISTS pw_pais;

CREATE OR REPLACE VIEW pw_pais AS 
 SELECT p.pais AS pais_codigo_pk,
    p.painome AS pais_descricao
   FROM pais p
  ORDER BY p.painome;  
  
  
-- ### pw_condicao_pagto ###  
DROP VIEW IF EXISTS pw_condicao_pagto;

CREATE OR REPLACE VIEW pw_condicao_pagto AS 
 SELECT condpag.condicao AS condicaopagto_codigo_pk,
    condpag.connome AS condicaopagto_descricao
   FROM condpag
  ORDER BY condpag.connome;
  

-- ### pw_deposito ###  
DROP VIEW IF EXISTS pw_deposito;

CREATE OR REPLACE VIEW pw_deposito AS 
 SELECT d.deposito AS deposito_codigo_pk,
    d.depnome AS deposito_descricao,
    d.deposito AS deposito_filial_codigo,
    d.depnome AS deposito_filial_descricao,
    d.depdepman AS deposito_subgrupo_codigo,
    d.depdepman AS deposito_grupo_codigo
   FROM deposito d
  ORDER BY d.deposito;  


-- ### pw_regiao_carga ###  
DROP VIEW IF EXISTS pw_regiao_carga;

CREATE OR REPLACE VIEW pw_regiao_carga AS 
 SELECT r.rgccod AS regiaocarga_codigo_pk,
    r.rgcdes AS regiaocarga_descricao
   FROM regcar r
  ORDER BY r.rgccod; 


-- ### pw_grupo_economico ###
DROP VIEW IF EXISTS pw_grupo_economico;

CREATE OR REPLACE VIEW pw_grupo_economico AS 
 SELECT ge.grecodigo AS grupoeconomico_codigo_pk,
    ge.gredescri AS grupoeconomico_descricao
   FROM grupeco ge
  ORDER BY ge.grecodigo; 

  
-- ### pw_empresa ###  
DROP VIEW IF EXISTS pw_empresa;

CREATE OR REPLACE VIEW pw_empresa AS 
 SELECT e.empresa AS empresa_codigo_pk,
	e.empnome AS empresa_descricao,
	e.empfanta AS empresa_nome_fantasia,
	e.empbairro AS empresa_bairro,
	e.empemail AS empresa_email_padrao,
	e.empmainfe AS empresa_email_danfe,
	e.empmaibol AS empresa_email_boletos,
	e.empmaicte AS empresa_email_cte,
	e.empcidade AS empresa_cidade_codigo_fk,
	CASE
		WHEN e.empstatus = 'I'  THEN 'Inativo'::text
		ELSE 'Ativo'::text
	END AS empresa_status,
    g.grecodigo AS empresa_grupo_economico_codigo_fk,
    c.cmeabrcod AS empresa_macro_regiao_codigo_fk,
    c.cmeabrmcod AS empresa_regiao_abrangencia_codigo_fk
   FROM empresa e
   LEFT JOIN (select gr.grecodigo, gr.grempresa from grupeco1 gr) as g on (g.grempresa = e.empresa) 
   LEFT JOIN (select cm.cmempresa, cm.cmeabrcod, cm.cmeabrmcod from cmempres cm) as c on (c.cmempresa = e.empresa)
  ORDER BY e.empnome;


-- ### pw_assistente_tecnico ###  
DROP VIEW IF EXISTS pw_assistente_tecnico;

CREATE OR REPLACE VIEW pw_assistente_tecnico AS 
 SELECT e.empresa AS assistentetecnico_codigo_pk,
	e.empnome AS assistentetecnico_descricao,
	e.empfanta AS assistentetecnico_nome_fantasia,
	e.empemail AS assistentetecnico_email_padrao,
	CASE
		WHEN e.empstatus = 'I'  THEN 'Inativo'::text
		ELSE 'Ativo'::text
	END AS assistentetecnico_status
   FROM empresa e
 Where e.emptipo = 5
  ORDER BY e.empnome;


-- ### pw_tipo_grupo_produto ###  
DROP VIEW IF EXISTS pw_tipo_grupo_produto;

CREATE OR REPLACE VIEW pw_tipo_grupo_produto AS 
 SELECT t.tgrucod AS tipogrupoproduto_codigo_pk,
    t.tgrudesc AS tipogrupoproduto_descricao
   FROM tipgrupo t
  ORDER BY t.tgrucod;  


-- ### pw_grupo_produto ###   
DROP VIEW IF EXISTS pw_grupo_produto;

CREATE OR REPLACE VIEW pw_grupo_produto AS 
 SELECT g.grupo AS grupoproduto_codigo_pk,
    g.grunome AS grupoproduto_descricao,
    g.tgrucod AS grupoproduto_tipo_grupo_produto_codigo_fk
   FROM grupo g
  ORDER BY g.grupo;


-- ### pw_subgrupo_produto ###   
DROP VIEW IF EXISTS pw_subgrupo_produto;
  
CREATE OR REPLACE VIEW pw_subgrupo_produto AS 
 SELECT s.grupo AS subgrupoproduto_grupo_codigo,
    s.subgrupo AS subgrupoproduto_codigo_pk,
    s.subnome AS subgrupoproduto_descricao
   FROM grupo1 s
  ORDER BY s.grupo, s.subgrupo;  
  
  

-- ### pw_produto ###  
DROP VIEW IF EXISTS pw_produto;

CREATE OR REPLACE VIEW pw_produto AS 
 SELECT p.produto AS produto_codigo_pk,
    p.pronome AS produto_descricao,
    p.grupo AS produto_grupo_produto_codigo_fk,
    p.subgrupo AS produto_subgrupo_produto_codigo_fk,
    coalesce(cf.cprefpba,p.produto) AS produto_produto_base_codigo_fk
   FROM produto p
   LEFT JOIN (select distinct on (c.cprefpco) c.cprefpba, c.cprefpco from confref c) as cf on (cf.cprefpco = p.produto) 
  ORDER BY p.pronome;



-- ### pw_produto_base ###  
DROP VIEW IF EXISTS pw_produto_base;

CREATE OR REPLACE VIEW pw_produto_base AS 
 SELECT p.produto AS produtobase_codigo_pk,
    p.pronome AS produtobase_descricao
   FROM produto p   
  ORDER BY p.pronome;


  
-- ### pw_tipo_venda ###  
DROP VIEW IF EXISTS pw_tipo_venda;

CREATE OR REPLACE VIEW pw_tipo_venda AS 
 SELECT t.tipoped AS tipovenda_codigo_pk,
    t.tpenome AS tipovenda_descricao
   FROM tipoped t
  ORDER BY t.tipoped;  
  

-- ### pw_tipo_assistencia ###  
DROP VIEW IF EXISTS pw_tipo_assistencia;

CREATE OR REPLACE VIEW pw_tipo_assistencia AS 
 SELECT t.tacodi AS tipoassistencia_codigo_pk,
    t.tadesc AS tipoassistencia_descricao
   FROM tipoass t
  ORDER BY t.tacodi;
  
-- ### pw_tipo_compra ###  
DROP VIEW IF EXISTS pw_tipo_compra;

CREATE OR REPLACE VIEW pw_tipo_compra AS 
 SELECT t.tpctipo AS tipocompra_codigo_pk,
    t.tpcdesc AS tipocompra_descricao
   FROM tipocomp t
  ORDER BY t.tpctipo;   
  
  
-- ### pw_motivo_assistencia ###  
DROP VIEW IF EXISTS pw_motivo_assistencia;

CREATE OR REPLACE VIEW pw_motivo_assistencia AS 
 SELECT m.asmtcod AS motivoassistencia_codigo_pk,
    m.asmtdesc AS motivoassistencia_descricao
   FROM assmoti m
  ORDER BY m.asmtcod;
  
  
  -- ### pw_acao_assistencia ###  
DROP VIEW IF EXISTS pw_acao_assistencia;

CREATE OR REPLACE VIEW pw_acao_assistencia AS 
 SELECT a.acocod AS acaoassistencia_codigo_pk,
    a.acodesc AS acaoassistencia_descricao
   FROM acoesas a
  ORDER BY a.acocod;

  
 
-- ### pw_vendedor ###  
DROP VIEW IF EXISTS pw_vendedor;

CREATE OR REPLACE VIEW pw_vendedor AS
 SELECT v1.vendedor AS vendedor_codigo_pk,
	v1.vennome AS vendedor_descricao,
	v1.abrcod AS vendedor_regiao_venda_codigo_fk,
	coalesce(v2.vennome,'SEM COORDENADOR 1')::text AS vendedor_coordenador1,
	v2.venemail AS vendedor_coordenador1_email,       
	coalesce(v3.vennome,'SEM COORDENADOR 2')::text AS vendedor_coordenador2,                
	v3.venemail AS vendedor_coordenador2_email,
        CASE    
		WHEN v1.venstatus = 'I'  THEN 'Inativo'::text
		ELSE 'Ativo'::text
	END AS vendedor_status,
	v1.venemail AS vendedor_email
   FROM vendedor v1
   LEFT JOIN (select ven1.vendedor, ven1.vennome, ven1.venemail from vendedor ven1) as v2 on (v1.vendedor = v1.vencodsup) 
   LEFT JOIN (select ven2.vendedor, ven2.vennome, ven2.venemail from vendedor ven2) as v3 on (v2.vendedor = v1.vencodsu2)
  ORDER BY v1.vennome;
  
  
-- ### pw_comprador ###  
DROP VIEW IF EXISTS pw_comprador;

CREATE OR REPLACE VIEW pw_comprador AS
 SELECT c.comprador AS comprador_codigo_pk,
	c.compnome AS comprador_descricao,
	c.compcargo AS comprador_cargo,	
	c.compemail AS comprador_email
   FROM comprado c
  ORDER BY c.compnome;


  
 -- ### pw_regiao_venda ###  
 DROP VIEW IF EXISTS pw_regiao_venda;
 
 CREATE OR REPLACE VIEW pw_regiao_venda AS 
 SELECT a.abrcod AS regiaovenda_codigo_pk,
    a.abrdes AS regiaovenda_descricao
   FROM abrange a
  ORDER BY a.abrcod;

  
  
-- ### pw_transacao ###  
DROP VIEW IF EXISTS pw_transacao;
 
CREATE OR REPLACE VIEW pw_transacao AS 
 SELECT t.transacao AS transacao_codigo_pk,
    t.trsnome AS transacao_descricao
   FROM transa t
  ORDER BY t.transacao;


-- ### pw_tipo_titulo ###  
DROP VIEW IF EXISTS pw_tipo_titulo;
 
CREATE OR REPLACE VIEW pw_tipo_titulo AS 
 SELECT tt.prtipo AS tipotitulo_codigo_pk,
    tt.prtnome AS tipotitulo_descricao
   FROM prtipo tt
  ORDER BY tt.prtipo;


-- ### pw_tipo_titulo_sintetico ###  
DROP VIEW IF EXISTS pw_tipo_titulo_sintetico;
 
CREATE OR REPLACE VIEW pw_tipo_titulo_sintetico AS 
 SELECT p.planoc AS tipotitulosintetico_codigo_pk,
    p.plcnome AS tipotitulosintetico_descricao
   FROM planoc p
  ORDER BY p.planoc;


-- ### pw_mod_cobranca ###  
DROP VIEW IF EXISTS pw_mod_cobranca;
 
CREATE OR REPLACE VIEW pw_mod_cobranca AS 
 SELECT mc.modcobra AS modcobranca_codigo_pk,
    mc.modnome AS modcobranca_descricao
   FROM modcobra mc
  ORDER BY mc.modcobra;


-- ### pw_tabela_venda ###  
DROP VIEW IF EXISTS pw_tabela_venda;
 
CREATE OR REPLACE VIEW pw_tabela_venda AS 
 SELECT tv.ttpvcod AS tabelavenda_codigo_pk,
    tv.ttpvdes AS tabelavenda_descricao
   FROM tptabprv tv
  ORDER BY tv.ttpvcod;


-- ### pw_portador ###  
DROP VIEW IF EXISTS pw_portador;
 
CREATE OR REPLACE VIEW pw_portador AS 
 SELECT b.banco AS portador_codigo_pk,
    b.bannome AS portador_descricao
   FROM banco b
  ORDER BY b.banco;

  
  -- ### pw_banco ###  
DROP VIEW IF EXISTS pw_banco;
 
CREATE OR REPLACE VIEW pw_banco AS 
 SELECT b.banco AS banco_codigo_pk,
    b.bannome AS banco_descricao
   FROM banco b
  ORDER BY b.banco;


-- ### pw_plano_contas ###  
DROP VIEW IF EXISTS pw_plano_contas;
 
CREATE OR REPLACE VIEW pw_plano_contas AS 
 SELECT p.planoc AS planocontas_codigo_pk,
    p.plcnome AS planocontas_descricao
   FROM planoc p
  ORDER BY p.planoc;


-- ### pw_centro_custo ###  
DROP VIEW IF EXISTS pw_centro_custo;
 
CREATE OR REPLACE VIEW pw_centro_custo AS 
 SELECT c.ccusto AS centrocusto_codigo_pk,
    c.ccunome AS centrocusto_descricao
   FROM ccusto c
  ORDER BY c.ccusto;


-- ### pw_ccusto_credito ###  
DROP VIEW IF EXISTS pw_ccusto_credito;
 
CREATE OR REPLACE VIEW pw_ccusto_credito AS 
 SELECT c.ccusto AS ccustocredito_codigo_pk,
    c.ccunome AS ccustocredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;  
  
  
-- ### pw_ccusto_debito ###  
DROP VIEW IF EXISTS pw_ccusto_debito;
 
CREATE OR REPLACE VIEW pw_ccusto_debito AS 
 SELECT c.ccusto AS ccustodebito_codigo_pk,
    c.ccunome AS ccustodebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;  
  
  
-- ### pw_ccusto_juros_credito ###  
DROP VIEW IF EXISTS pw_ccusto_juros_credito;
 
CREATE OR REPLACE VIEW pw_ccusto_juros_credito AS 
 SELECT c.ccusto AS ccustojuroscredito_codigo_pk,
    c.ccunome AS ccustojuroscredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto; 
  
  
-- ### pw_ccusto_juros_debito ###  
DROP VIEW IF EXISTS pw_ccusto_juros_debito;
 
CREATE OR REPLACE VIEW pw_ccusto_juros_debito AS 
 SELECT c.ccusto AS ccustojurosdebito_codigo_pk,
    c.ccunome AS ccustojurosdebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;
  

-- ### pw_ccusto_desconto_credito ###  
DROP VIEW IF EXISTS pw_ccusto_desconto_credito;
 
CREATE OR REPLACE VIEW pw_ccusto_desconto_credito AS 
 SELECT c.ccusto AS ccustodescontocredito_codigo_pk,
    c.ccunome AS ccustodescontocredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;
  
  
-- ### pw_ccusto_desconto_debito ###  
DROP VIEW IF EXISTS pw_ccusto_desconto_debito;
 
CREATE OR REPLACE VIEW pw_ccusto_desconto_debito AS 
 SELECT c.ccusto AS ccustodescontodebito_codigo_pk,
    c.ccunome AS ccustodescontodebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;  
  
  
-- ### pw_ccusto_tarifa_credito ###  
DROP VIEW IF EXISTS pw_ccusto_tarifa_credito;
 
CREATE OR REPLACE VIEW pw_ccusto_tarifa_credito AS 
 SELECT c.ccusto AS ccustotarifacredito_codigo_pk,
    c.ccunome AS ccustotarifacredito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;
  
  
-- ### pw_ccusto_tarifa_debito ###  
DROP VIEW IF EXISTS pw_ccusto_tarifa_debito;
 
CREATE OR REPLACE VIEW pw_ccusto_tarifa_debito AS 
 SELECT c.ccusto AS ccustotarifadebito_codigo_pk,
    c.ccunome AS ccustotarifadebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto;  
  
  
-- ### pw_ccusto_iof_debito ###  
DROP VIEW IF EXISTS pw_ccusto_iof_debito;
 
CREATE OR REPLACE VIEW pw_ccusto_iof_debito AS 
 SELECT c.ccusto AS ccustoiofdebito_codigo_pk,
    c.ccunome AS ccustoiofdebito_descricao
   FROM ccusto c
  ORDER BY c.ccusto; 
  
  
-- ### pw_lote_producao ###  
DROP VIEW IF EXISTS pw_lote_producao;
 
CREATE OR REPLACE VIEW pw_lote_producao AS 
 SELECT l.lotcod AS loteproducao_codigo_pk,
    l.lotdes AS loteproducao_descricao
   FROM loteprod l
  ORDER BY l.lotcod;




-- ### pw_tipo_ordem ###  
DROP VIEW IF EXISTS pw_tipo_ordem;
 
CREATE OR REPLACE VIEW pw_tipo_ordem AS 
 SELECT t.tipoord AS tipoordem_codigo_pk,
    t.tornome AS tipoordem_descricao
   FROM tipoord t
  ORDER BY t.tipoord;
  
  
  -- ### pw_conta_debito ###  
DROP VIEW IF EXISTS pw_conta_debito;
 
CREATE OR REPLACE VIEW pw_conta_debito AS 
 SELECT p.planoc AS contadebito_codigo_pk,
    p.plcnome AS contadebito_descricao
   FROM planoc p
  ORDER BY p.planoc;
  

-- ### pw_conta_reduzida_debito ###  
DROP VIEW IF EXISTS pw_conta_reduzida_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_debito AS 
select distinct
       r.conta::character(15) as contareduzidadebito_codigo_pk,
       r.conta::character(15) as contareduzidadebito_descricao
  from (
              select c.ctbconclie as conta
                from ctbconem c
              union all
              select f.ctbconforn as conta
                from ctbconem f
              union all
              select p.plcproc as conta
                from planoc p
       ) as r;  
   
-- ### pw_conta_credito ###  
DROP VIEW IF EXISTS pw_conta_credito;
 
CREATE OR REPLACE VIEW pw_conta_credito AS 
 SELECT p.planoc AS contacredito_codigo_pk,
    p.plcnome AS contacredito_descricao
   FROM planoc p
  ORDER BY p.planoc;
  

-- ### pw_conta_reduzida_credito ###  
DROP VIEW IF EXISTS pw_conta_reduzida_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_credito AS 
select distinct
       r.conta::character(15) as contareduzidacredito_codigo_pk,
       r.conta::character(40) as contareduzidacredito_descricao
  from (
              select c.ctbconclie as conta
                from ctbconem c
              union all
              select f.ctbconforn as conta
                from ctbconem f
              union all
              select p.plcproc as conta
                from planoc p
       ) as r;

  
-- ### pw_conta_juros_credito ###  
DROP VIEW IF EXISTS pw_conta_juros_credito;
 
CREATE OR REPLACE VIEW pw_conta_juros_credito AS 
 SELECT p.planoc AS contajuroscredito_codigo_pk,
    p.plcnome AS contajuroscredito_descricao
   FROM planoc p
  ORDER BY p.planoc; 
  

-- ### pw_conta_reduzida_juros_credito ###  
DROP VIEW IF EXISTS pw_conta_reduzida_juros_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_juros_credito AS 
select distinct
       p.plcproc as contareduzidajuroscredito_codigo_pk,
       p.plcproc as contareduzidajuroscredito_descricao
  from planoc p;
  
-- ### pw_conta_juros_debito ###  
DROP VIEW IF EXISTS pw_conta_juros_debito;
 
CREATE OR REPLACE VIEW pw_conta_juros_debito AS 
 SELECT p.planoc AS contajurosdebito_codigo_pk,
    p.plcnome AS contajurosdebito_descricao
   FROM planoc p
  ORDER BY p.planoc;   
  

-- ### pw_conta_reduzida_juros_debito ###  
DROP VIEW IF EXISTS pw_conta_reduzida_juros_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_juros_debito AS 
select distinct
       p.plcproc as contareduzidajurosdebito_codigo_pk,
       p.plcproc as contareduzidajurosdebito_descricao
  from planoc p;
  
  
-- ### pw_conta_desconto_credito ###  
DROP VIEW IF EXISTS pw_conta_desconto_credito;
 
CREATE OR REPLACE VIEW pw_conta_desconto_credito AS 
 SELECT p.planoc AS contadescontocredito_codigo_pk,
    p.plcnome AS contadescontocredito_descricao
   FROM planoc p
  ORDER BY p.planoc;  
  
 -- ### pw_conta_reduzida_desconto_credito ###  
DROP VIEW IF EXISTS pw_conta_reduzida_desconto_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_desconto_credito AS 
select distinct
       p.plcproc as contareduzidadescontocredito_codigo_pk,
       p.plcproc as contareduzidadescontocredito_descricao
  from planoc p; 
  
  
-- ### pw_conta_desconto_debito ###  
DROP VIEW IF EXISTS pw_conta_desconto_debito;
 
CREATE OR REPLACE VIEW pw_conta_desconto_debito AS 
 SELECT p.planoc AS contadescontodebito_codigo_pk,
    p.plcnome AS contadescontodebito_descricao
   FROM planoc p
  ORDER BY p.planoc;    
  
  
-- ### pw_conta_reduzida_desconto_debito ###  
DROP VIEW IF EXISTS pw_conta_reduzida_desconto_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_desconto_debito AS 
select distinct
       p.plcproc::character(15) as contareduzidadescontodebito_codigo_pk,
       p.plcproc::character(40) as contareduzidadescontodebito_descricao
  from planoc p; 
  
  
-- ### pw_conta_tarifa_credito ###  
DROP VIEW IF EXISTS pw_conta_tarifa_credito;
 
CREATE OR REPLACE VIEW pw_conta_tarifa_credito AS 
 SELECT p.planoc AS contatarifacredito_codigo_pk,
    p.plcnome AS contatarifacredito_descricao
   FROM planoc p
  ORDER BY p.planoc;  
  

 -- ### pw_conta_reduzida_tarifa_credito ###  
DROP VIEW IF EXISTS pw_conta_reduzida_tarifa_credito;

CREATE OR REPLACE VIEW pw_conta_reduzida_tarifa_credito AS 
select distinct
       p.plcproc as contareduzidatarifacredito_codigo_pk,
       p.plcproc as contareduzidatarifacredito_descricao
  from planoc p;  
  
  
-- ### pw_conta_tarifa_debito ###  
DROP VIEW IF EXISTS pw_conta_tarifa_debito;
 
CREATE OR REPLACE VIEW pw_conta_tarifa_debito AS 
 SELECT p.planoc AS contatarifadebito_codigo_pk,
    p.plcnome AS contatarifadebito_descricao
   FROM planoc p
  ORDER BY p.planoc;   


-- ### pw_conta_reduzida_tarifa_debito ###  
DROP VIEW IF EXISTS pw_conta_reduzida_tarifa_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_tarifa_debito AS 
select distinct
       p.plcproc as contareduzidatarifadebito_codigo_pk,
       p.plcproc as contareduzidatarifadebito_descricao
  from planoc p; 

  
-- ### pw_conta_iof_debito ###  
DROP VIEW IF EXISTS pw_conta_iof_debito;
 
CREATE OR REPLACE VIEW pw_conta_iof_debito AS 
 SELECT p.planoc AS contaiofdebito_codigo_pk,
    p.plcnome AS contaiofdebito_descricao
   FROM planoc p
  ORDER BY p.planoc;   
  
  
  
DROP VIEW IF EXISTS pw_conta_reduzida_iof_debito;

CREATE OR REPLACE VIEW pw_conta_reduzida_iof_debito AS 
select distinct
       p.plcproc as contareduzidaiofdebito_codigo_pk,
       p.plcproc as contareduzidaiofdebito_descricao
  from planoc p; 
	     
 -- ### pw_transacao_financeira ###  
DROP VIEW IF EXISTS pw_transacao_financeira;
 
CREATE OR REPLACE VIEW pw_transacao_financeira AS 
	select unnest(array['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'k', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', '#', 'X', 'Y', 'Z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) as transacaofinanceira_codigo_pk,
	unnest(array['Débitos Bancários Múltiplos', 'Adiantamento Banco', 'Adiantamento Caixa', 'Depósito Bancário', 'Entrada Bancária', 'Depósito de Cheques', 'Recebimentos Múltiplos', 'Créditos Bancários Múltiplos', 'Saque Múltiplo', 'Desconto de Cheques', 'Compensação de Cartões', 'Pagamentos Múltiplos', 'Duplicatas Descontadas', 'Saída ( Pagto ) Caixa', 'Saída Bancária', 'Entrada ( Recto ) Caixa', 'Saque Bancário', 'Saída entre Bancos', 'Entrada entre Bancos', 'Devoluções de Vendas', 'Devoluções de Compras', 'Pagamentos Extra Caixa', 'Troca de Cheque por Dinheiro', 'Recebimentos Extra Caixa', 'Pag. Extra Caixa -> Contab', 'Adiantamento Clientes', 'Adiantamento Clientes /Banco', 'Adiantamento Fornecedores', 'Adiantamento Fornec. /Banco', 'Devolução Adiant. Clientes', 'Devol. Adiant. Clientes /Banco', 'Devol. Adiantamento Fornecedores', 'Devol. Adiant.Fornec. /Banco', 'Receb. Extra Caixa -> Contab']) as transacaofinanceira_descricao;

-- ### pw_tipo_movimentacao ###  
DROP VIEW IF EXISTS pw_tipo_movimentacao;
 
CREATE OR REPLACE VIEW pw_tipo_movimentacao AS 
select unnest(array['S', 'N']) as tipomovimentacao_codigo_pk,
       unnest(array['Extra Caixa', 'Não Extra Caixa']) as tipomovimentacao_decricao;
	
 -- ### pw_fase_producao ### 	
DROP VIEW IF EXISTS pw_fase_producao;

CREATE OR REPLACE VIEW pw_fase_producao AS 
 SELECT f.fase AS faseproducao_codigo_pk,
    f.fasnome AS faseproducao_descricao
   FROM fases f
  ORDER BY f.fase;	
  
-- ### pw_funcionario ### 	
DROP VIEW IF EXISTS pw_funcionario;

CREATE OR REPLACE VIEW pw_funcionario AS 
 SELECT f.funciona AS funcionario_codigo_pk,
    f.funnome AS funcionario_nome
   FROM funciona f
  ORDER BY f.funciona;

 -- ### pw_motivo_parada ### 	
DROP VIEW IF EXISTS pw_motivo_parada;

CREATE OR REPLACE VIEW pw_motivo_parada AS 
 SELECT m.prdcodi AS motivoparada_codigo_pk,
    m.prddesc AS motivoparada_descricao
   FROM paradas m
  ORDER BY m.prdcodi;
  
 -- ### pw_maquina ### 	
DROP VIEW IF EXISTS pw_maquina;

CREATE OR REPLACE VIEW pw_maquina AS 
 SELECT mq.maquina AS maquina_codigo_pk,
    mq.maqnome AS maquina_descricao
   FROM maquina mq
  ORDER BY mq.maquina;
 
   -- ### pw_operacao ### 	
DROP VIEW IF EXISTS pw_operacao;

CREATE OR REPLACE VIEW pw_operacao AS 
 SELECT op.oppcodi AS operacao_codigo_pk,
    op.oppdesc AS operacao_descricao
   FROM opproc op
  ORDER BY op.oppcodi;

  -- ### pw_processo ### 	
DROP VIEW IF EXISTS pw_processo;

CREATE OR REPLACE VIEW pw_processo AS 
 SELECT proc.processo AS processo_codigo_pk,
	proc.produto As produto_codigo_fk,
    proc.prcnome AS processo_descricao,
    proc.prccodig As processo_operacao_codigo_fk
   FROM processo proc
  ORDER BY proc.produto;