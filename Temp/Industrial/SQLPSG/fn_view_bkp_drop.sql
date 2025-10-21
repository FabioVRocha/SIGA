-- Function: fn_view_bkp_drop()

-- DROP FUNCTION fn_view_bkp_drop();

CREATE OR REPLACE FUNCTION fn_view_bkp_drop()
  RETURNS void AS
$BODY$
DECLARE 
    item record;
    qtd_views integer;
BEGIN    
    qtd_views = 0;

    /*[09/10/2023, 3925923, Ricardo K] Faz bkp e drop das views conforme o bkp.*/
        
    IF not exists(SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'bkp_schema') THEN
    
        --cria o schema onde estarao os bkps das views
        create schema bkp_schema;
    
    END IF;

    
    IF not exists(SELECT table_name FROM information_schema.tables WHERE table_schema = 'bkp_schema' AND table_name = 'views_public') THEN
        RAISE NOTICE 'Criando tabela "bkp_schema.views_public" para armazenar as views durante a atualização.';
        
        --Faz o bkp de todas as views existentes no sistema (desconsiderando as views dos schemas do postgres)
        create table bkp_schema.views_public (
            table_schema TEXT,
            table_name TEXT, 
            view_definition TEXT,  
            horario_bkp timestamp,
            tipo TEXT,
            parametros TEXT,
            dependentes text[],
            ordem_criacao int
        );
    END IF;        
    --essa forma recursiva deve atender qualquer nível, pois fará o drop partindo dos níveis mais baixos, porém não compara o schema da view, então somente PUBLIC está sendo tratada
    /*
     * Lê todas as views existentes do chema PUBLIC e realiza o BKP e DROP delas.
     */
    FOR item IN
        WITH RECURSIVE views AS (
        
            --Busca as views
            SELECT table_name, 
            format('create or replace view %s.%s as %s', table_schema, TABLE_name, view_definition) AS view_definition, 
            table_schema, 
            'view' AS tipo, 
            '' AS parametros
            FROM information_schema.views 
            where table_schema = 'public' /*table_schema not in ('pg_catalog','information_schema')*/
                AND table_name NOT IN (
                    --Ignora views criadas por extensões (não funciona em postgres 9.0, testado 9.3+, TALVEZ funcione a partir do 9.1 )
                    SELECT c.relname AS view_name
                    FROM pg_class c
                    JOIN pg_depend d ON c.oid = d.objid
                    JOIN pg_extension e ON d.refobjid = e.oid
                )
            
            UNION
            
             --Busca as funções
            SELECT proname AS function_name, 
                format('create or replace function %s.%s(%s) returns %s LANGUAGE plpgsql AS $wololo$ %s $wololo$', nspname, proname, pg_get_function_arguments(p.oid), pg_get_function_result(p.oid), prosrc) AS source_code, 
                nspname AS schema_name, 
                'function' AS tipo,
                format('(%s)', pg_get_function_arguments(p.oid)) AS parametros
--                ,pg_get_function_result(p.oid) AS retorno
            FROM pg_proc p
            LEFT JOIN pg_namespace ON (pg_namespace.oid = p.pronamespace)
            WHERE nspname = 'public'
                AND proname NOT IN (
                   
                   --ignorando funções dependentes de extensões 
                    SELECT c.proname
                    FROM pg_proc c
                    JOIN pg_depend d ON c.oid = d.objid
                    JOIN pg_extension e ON d.refobjid = e.oid
                    
                    union
                    
                    --ignorando funções dependentes de triggers
                    SELECT 
                        proname
                    FROM 
                        pg_trigger
                    JOIN 
                        pg_proc ON tgfoid = pg_proc.oid
                )
                AND proname NOT IN ('fn_view_bkp_drop', 'fn_execute', 'fn_view_bkp_restore')
        ),
        relacionamento AS (
        
            SELECT pai.*, filho.table_name AS view_dependente 
            FROM views pai
            LEFT JOIN views filho ON (filho.view_definition ILIKE '%' || pai.table_name || '%' AND pai.table_name <> filho.table_name)
            ORDER BY filho.table_name DESC
            
        ), 
        dependencias (table_name, table_schema, view_definition, nivel, tipo, view_dependente) AS (
            
            --seleciona todos as views/functions nivel zero (não possuem dependência) e depois usa a recursão para fazer o union delas
            SELECT table_name, table_schema, view_definition, 0 AS nivel, tipo, view_dependente, parametros
            --, views_dependentes
            FROM relacionamento
            WHERE view_dependente IS null
            
            UNION 
           
            SELECT filho.table_name, filho.table_schema, filho.view_definition, pai.nivel + 1 AS nivel, filho.tipo, filho.view_dependente, filho.parametros
            FROM dependencias pai
            INNER JOIN relacionamento filho ON (
                --definição do pai possui a chamada do filho (verificação de dependência)                
                pai.view_definition ILIKE '%' || filho.table_name || '%' 
                --não é a mesma tabela (ignora a própria tabela para ela não ser considerada dependência de si própria)
                AND pai.table_name <> filho.table_name
                --falta critério para impedir recursão infinita e apenas limite de níveis não parece uma boa forma
                AND TRUE --NOT EXISTS (SELECT table_name, view_dependente FROM dependencias WHERE table_name = filho.table_name AND view_dependente = filho.view_dependente)
                )
            --limite de níveis que pode descer, pois há multiplas funções recursivas que se chamam entre si (referência circular)     
            WHERE nivel < 15 
            
        ),
        agrupado_com_dependentes AS (
            SELECT table_schema, table_name, max(nivel) AS nivel_mais_alto, view_definition, tipo, parametros, array_agg(view_dependente) AS views_dependentes
            FROM dependencias
            GROUP BY table_schema, table_name, view_definition, tipo, parametros
            ORDER BY max(nivel) ASC, table_name
        )
        --Filtra todas as views e o que existir como dependencia de alguma vie e armazena uma coluna com a ordem de execuçãow.
        SELECT *, 
            ROW_NUMBER() OVER (ORDER BY nivel_mais_alto DESC, table_name desc) AS ordem_criacao 
        FROM agrupado_com_dependentes
        WHERE tipo = 'view'
            OR table_name IN (select UNNEST(views_dependentes) FROM agrupado_com_dependentes WHERE tipo = 'view')
        ORDER BY nivel_mais_alto ASC, table_name ASC
        
    LOOP
        RAISE NOTICE 'Armazenando e removendo a % "%.% %".', item.tipo, item.table_schema, item.table_name, item.parametros;
        
        INSERT INTO bkp_schema.views_public(table_name, view_definition, table_schema, horario_bkp, tipo, dependentes, ordem_criacao) VALUES (item.table_name, item.view_definition, item.table_schema, now(), item.tipo, item.views_dependentes, item.ordem_criacao); 
            
        RAISE NOTICE 'drop % %.% %;', item.tipo, item.table_schema, item.table_name, item.parametros;
        --https://stackoverflow.com/questions/42920998/pl-pgsql-perform-vs-execute ()
        EXECUTE format('drop %s %s.%s %s;', item.tipo, item.table_schema, item.table_name, item.parametros);
        
        qtd_views = qtd_views + 1;
    END LOOP;

    RAISE NOTICE 'Processo finalizado com sucesso com % views/functions armazenadas e removidas.', qtd_views;

END 
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION fn_view_bkp_drop()
  OWNER TO postgres;
