-- View: pw_vendedor

-- DROP VIEW pw_vendedor;

CREATE OR REPLACE VIEW pw_vendedor AS 
 SELECT v1.vendedor AS vendedor_codigo_pk,
    v1.vennome AS vendedor_descricao,
    v1.abrcod AS vendedor_regiao_venda_codigo_fk,
    COALESCE(v2.vennome, 'SEM COORDENADOR 1'::bpchar)::text AS vendedor_coordenador1,
    v2.venemail AS vendedor_coordenador1_email,
    COALESCE(v3.vennome, 'SEM COORDENADOR 2'::bpchar)::text AS vendedor_coordenador2,
    v3.venemail AS vendedor_coordenador2_email,
        CASE
            WHEN v1.venstatus = 'I'::bpchar THEN 'Inativo'::text
            ELSE 'Ativo'::text
        END AS vendedor_status,
    v1.venemail AS vendedor_email,
        CASE
            WHEN v1.vencpf = '   .   .   -  '::bpchar THEN ''::text
            ELSE v1.vencpf::text
        END AS vendedor_cpf,
        CASE
            WHEN v1.vencgc = '  .   .   /    -  '::bpchar THEN ''::text
            ELSE v1.vencgc::text
        END AS vendedor_cnpj,
    v1.ventelefo AS vendedor_telefone,
    v1.vencelu AS vendedor_celular,
    v1.vencicod AS vendedor_cidadevendedor_codigo_fk,
    v1.dventiprel AS vendedor_tipo_relacao
   FROM vendedor v1
     LEFT JOIN ( SELECT ven1.vendedor,
            ven1.vennome,
            ven1.venemail
           FROM vendedor ven1) v2 ON v2.vendedor = v1.vencodsup
     LEFT JOIN ( SELECT ven2.vendedor,
            ven2.vennome,
            ven2.venemail
           FROM vendedor ven2) v3 ON v3.vendedor = v1.vencodsu2
  ORDER BY v1.vennome;

ALTER TABLE pw_vendedor
  OWNER TO postgres;
