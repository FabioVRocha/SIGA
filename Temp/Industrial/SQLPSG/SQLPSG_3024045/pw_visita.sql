-- View: pw_visita

-- DROP VIEW pw_visita;

CREATE OR REPLACE VIEW pw_visita AS 
 SELECT v.visnumero AS visita_numero_pk,
    v.vendedor AS visita_vendedor_codigo_fk,
    v.visdata AS visita_data_visita,
    v.visproxi AS visita_data_proxima_visita,
    v.vistpcont AS visita_tipo_contato_codigo_fk,
    v.empresa AS visita_empresa_codigo_fk,
    e.empcidade AS visita_empresa_cidade_codigo_fk,
    v.pedido AS visita_nr_pedido_venda,
    v.visboletim AS visita_nr_boletim,
    v.vislconc AS visita_conceito,
        CASE
            WHEN v.vishrini = 0.00 THEN '0:00'::text
            ELSE replace(to_char(v.vishrini, 'FM99.00'::text), '.'::text, ':'::text)
        END AS visita_hora_inicial,
        CASE
            WHEN v.vishrfim = 0.00 THEN '0:00'::text
            ELSE replace(to_char(v.vishrfim, 'FM99.00'::text), '.'::text, ':'::text)
        END AS visita_hora_final,
    v.viskmini AS visita_km_inicial,
    v.viskmfim AS visita_km_final,
    ( SELECT string_agg(
                CASE
                    WHEN w.visnumero = v.visnumero::numeric THEN w.viscoment
                    ELSE NULL::bpchar
                END::text, ' '::text) AS string_agg
           FROM visita1 w) AS visita_comentario
   FROM visita v
     JOIN tipcont t ON t.tpcont = v.vistpcont
     JOIN empresa e ON e.empresa = v.empresa
  ORDER BY v.visnumero;

ALTER TABLE pw_visita
  OWNER TO postgres;
