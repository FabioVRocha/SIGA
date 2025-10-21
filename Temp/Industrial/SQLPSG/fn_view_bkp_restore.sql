-- Function: fn_view_bkp_restore()

-- DROP FUNCTION fn_view_bkp_restore();

CREATE OR REPLACE FUNCTION fn_view_bkp_restore()
  RETURNS void AS
$BODY$ 
DECLARE 
    item record;
    qtd_views_restauradas integer;
    qtd_views_ignoradas integer;
BEGIN    
    qtd_views_restauradas = 0;
    qtd_views_ignoradas = 0;

    /*[09/10/2023, 3925923, Ricardo K] Restaura as views do bkp que ainda não existem e remove ela do bkp.*/
    FOR item IN
      
            SELECT table_name, view_definition, table_schema, tipo, parametros, ordem_criacao
            FROM  bkp_schema.views_public
            where(table_schema,  table_name, tipo) NOT in (
                
                --Ignora views que já existem (foram criadas pelo industrial)
                SELECT table_schema::text,  table_name, 'view' AS tipo 
                FROM information_schema.views 
                where table_schema = 'public' /*table_schema not in ('pg_catalog','information_schema')*/

                UNION
                
                --Ignora funções que já existem
                SELECT nspname::text,  p.proname, 'function' AS tipo
                FROM pg_proc p
                LEFT JOIN pg_namespace ON (pg_namespace.oid = p.pronamespace)
                WHERE nspname = 'public' 
                
            )
            ORDER BY ordem_criacao ASC
       
    LOOP
        RAISE NOTICE 'Criando % %.%', item.tipo, item.table_schema, item.table_name; 
        EXECUTE item.view_definition;
        DELETE FROM bkp_schema.views_public WHERE table_name = item.table_name AND table_schema = item.table_schema;
        qtd_views_restauradas = qtd_views_restauradas + 1;
    END LOOP;
    
    /*Remove do bkp todas as views que já existem.*/
    FOR item IN ( 
        SELECT b.table_name, b.table_schema 
        FROM bkp_schema.views_public b
        LEFT JOIN information_schema.views v ON (b.table_name, b.table_schema) = (v.table_name, v.table_schema)
        where b.table_schema = 'public' /*table_schema not in ('pg_catalog','information_schema')*/ 
            AND v.table_name IS NOT null
    )
    LOOP
        RAISE NOTICE 'Ignorando view existente e removendo do bkp: %.%', item.table_schema, item.table_name; 
        DELETE FROM bkp_schema.views_public WHERE table_name = item.table_name AND table_schema = item.table_schema;
        qtd_views_ignoradas = qtd_views_ignoradas + 1;
    END LOOP;
    
    /*Remove tabela, função e schema que foram utilizados no processo.*/
    DROP TABLE bkp_schema.views_public;
    DROP SCHEMA bkp_schema;

    RAISE NOTICE 'Processo finalizado com sucesso com % views restauradas e % views ignoradas.', qtd_views_restauradas, qtd_views_ignoradas;
    
END 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_view_bkp_restore()
  OWNER TO postgres;
