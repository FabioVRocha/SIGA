import psycopg2
from psycopg2 import sql

conn = psycopg2.connect(host='45.161.184.156', port=5433, dbname='madresilva', user='postgres', password='postgres')
cur = conn.cursor()

search_num = 720980

cur.execute("""
    SELECT DISTINCT table_name
    FROM information_schema.columns
    WHERE table_schema = 'public' AND column_name ILIKE '%ordem%'
""")
tables = [row[0] for row in cur.fetchall()]

matches = []

for table in tables:
    cur.execute(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema=%s AND table_name=%s",
        ('public', table)
    )
    columns = cur.fetchall()
    numeric_cols = [row[0] for row in columns if row[1] in ('integer','bigint','numeric','double precision','real','smallint','decimal')]
    char_cols = [row[0] for row in columns if row[1] in ('character varying','character','text','bpchar')]

    found = False

    if numeric_cols:
        where = ' OR '.join([f"{col} = %s" for col in numeric_cols])
        query = sql.SQL('SELECT 1 FROM {} WHERE ' + where + ' LIMIT 1').format(sql.Identifier(table))
        params = tuple([search_num] * len(numeric_cols))
        cur.execute(query, params)
        if cur.fetchone():
            matches.append((table, 'numeric'))
            continue

    if char_cols:
        where = ' OR '.join([f"{col}::text ILIKE %s" for col in char_cols])
        query = sql.SQL('SELECT 1 FROM {} WHERE ' + where + ' LIMIT 1').format(sql.Identifier(table))
        params = tuple(['%' + str(search_num) + '%'] * len(char_cols))
        cur.execute(query, params)
        if cur.fetchone():
            matches.append((table, 'text'))

print(matches)

cur.close()
conn.close()
