-- Function: fn_busca_dados_lgpd(text, text[], text[], text)

-- DROP FUNCTION fn_busca_dados_lgpd(text, text[], text[], text);

CREATE OR REPLACE FUNCTION fn_busca_dados_lgpd(IN search_term text, IN param_tables text[] DEFAULT '{}'::text[], IN param_schemas text[] DEFAULT '{public}'::text[], IN progress text DEFAULT NULL::text)
  RETURNS TABLE(p_texto_buscado text, p_schema_nome text, p_tabela_nome text, p_qtd_registros bigint, p_horario timestamp without time zone) AS
$BODY$
declare
  query text;
  hit boolean;
  schemaname TEXT;
  tablename TEXT;
  registro record;
  qtd bigint;
BEGIN
    --Cria as tabelas de busca se n?oo existirem
    CREATE SCHEMA IF NOT EXISTS busca_lgpd;
    CREATE TABLE IF NOT EXISTS busca_lgpd.lgpdtabe(lgtxtbusc text, lgschema text, lgtabnome TEXT , lgqtdregis bigint, lghora timestamp, PRIMARY KEY (lgtxtbusc, lgschema, lgtabnome));    
    CREATE TABLE IF NOT EXISTS busca_lgpd.lgpddado(lgdid serial PRIMARY KEY, lgdtxtbusc text, lgdschema text, lgdtabnome TEXT, lgdhora timestamp, lgdchaves text, lgddados text, colunas_dados text[], lgdrota text);
    
    
    --Realiza a busca nas tabelas e schemas selecionados.
    FOR schemaname, tablename IN
        SELECT t.table_schema, t.table_name
        FROM information_schema.tables t
        LEFT JOIN information_schema.schemata s ON
            (s.schema_name=t.table_schema)
              --Considera filtros de tabelas e schemas, desconsiderando views.
        WHERE (t.table_name=ANY(param_tables) OR param_tables='{}')
            AND t.table_schema=ANY(param_schemas)
            AND t.table_type='BASE TABLE'
            --DESCONSIDERA tabelas que est?oo na lista de j? percorridas.
            AND NOT (t.table_schema, t.table_name) IN (SELECT lgschema, lgtabnome FROM busca_lgpd.lgpdtabe WHERE lgtxtbusc = search_term)
            --Considera apenas tabelas que o usu?rio atual possui permiss?oo de leitura
            AND EXISTS (
                SELECT 1 FROM information_schema.table_privileges p
                WHERE p.table_name=t.table_name
                    AND p.table_schema=t.table_schema
                    AND p.privilege_type='SELECT'
            )
            --ignora o schema que est? armazenando os dados encontrados, pois se gravarmos os registros nele, duplicar? tudo que foi encontrado quando ele for varrido.
            AND t.table_schema <> 'busca_lgpd'
            --solicitado pela J?ssica que as tabelas que comes?oam por 'um' (tempor?rias) fossem ignoradas.
            AND NOT (t.table_schema = 'public' AND t.table_name ILIKE 'um%')
        ORDER BY t.table_schema, t.table_name
        --apenas 1 tabela por vez para que o feedback seja mais r?pido, mas poderia fazer mais por vez, basta alterar ou parametrizar este LIMIT.
        LIMIT 50
    LOOP
        IF (progress in ('tables','all')) THEN
            raise info '%', format('Consultando: %I.%I', schemaname, tablename);
        END IF;
    
        --Utiliza a fun??o que busca em todas as colunas, retornando a PK e as colunas encontradas.
        qtd := 0;


        query := format(
            $SQL$
            
            SELECT %1$L as texto_buscado,
                %2$L as schema_nome, 
                %3$L as tabela_nome, 
                pk_val, colunas_encontradas, colunas_encontradas_array,
                ( select coalesce(prlrotsis, 'ROTA NAO CADASTRADA!') from prlgeral where prltabrel = %4$L limit 1 ) as rota
            FROM fn_buscar_em_todas_as_colunas( %2$L, %3$L, %1$L ) 
            
            --Foi optado por n?o considerar as rotas por coluna ent?o sup?e-se que todas as colunas da tabela possuem a mesma rota.
            --LEFT JOIN prlgeral ON lgdtabnome = lower(trim(prlnomtab)) AND lower(trim(prlcoltab)) = ANY(colunas)

            $SQL$,
            search_term,
            schemaname,
            tablename,
            upper(tablename)
        );


--        raise info '%', format('Consultando: %s', query);
        
        FOR registro IN EXECUTE query
        LOOP

            --Cadastra na tabela de rotas a tabela que em que foram encontrados dados, caso ela ainda n?oo exista.
            INSERT INTO prlgeral (prlnomtab, prlcoltab, prltabrel, prlcolrel, prlrotsis) 
            SELECT '', '', upper(tablename), '', 'ROTA NAO CADASTRADA!' 
            WHERE NOT exists( SELECT * FROM prlgeral WHERE prltabrel = upper(tablename) );

            --Conta a qtd de registros encontrados em cada tabela;
            qtd := qtd + 1;
        
            --Insere os dados encontrados
            INSERT INTO busca_lgpd.lgpddado(lgdtxtbusc, lgdschema, lgdtabnome, lgdhora, lgdchaves, lgddados, colunas_dados, lgdrota)
                VALUES (search_term, registro.schema_nome, registro.tabela_nome, current_timestamp, registro.pk_val, registro.colunas_encontradas, registro.colunas_encontradas_array, registro.rota);
        
            IF (progress in ('all')) THEN
                raise info '%', format('%L em %I.%I: %L', search_term, registro.schema_nome, registro.tabela_nome, registro.colunas_encontradas);
            END IF;
    
        END LOOP; -- for registro
        
        --Insere que a tabela j? foi buscada e X registros foram encontrados.
        INSERT INTO busca_lgpd.lgpdtabe(lgtxtbusc, lgschema, lgtabnome, lgqtdregis, lghora) VALUES (search_term, schemaname, tablename, qtd, current_timestamp);
        
        --A cada tabela, sai fora. 
        RETURN query SELECT * FROM busca_lgpd.lgpdtabe WHERE (lgtxtbusc, lgschema, lgtabnome) = (search_term, schemaname, tablename);
--        RETURN query SELECT * FROM busca_lgpd.lgpdtabe WHERE lgtxtbusc = search_term and lgschema = schemaname AND lgtabnome = tablename;
    
    END LOOP; -- for table
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION fn_busca_dados_lgpd(text, text[], text[], text)
  OWNER TO postgres;
