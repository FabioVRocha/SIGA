import psycopg2
from psycopg2 import sql

conn = psycopg2.connect(host='45.161.184.156', port=5433, dbname='madresilva', user='postgres', password='postgres')
cur = conn.cursor()

search_value = '720980'

cur.execute("""
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
""")
tables = [row[0] for row in cur.fetchall()]

matches = []

for table in tables:
    cur.execute(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema=%s AND table_name=%s",
        ('public', table)
    )
    columns = cur.fetchall()
    text_cols = [row[0] for row in columns if row[1] in ('character varying','character','text','bpchar')]
    numeric_cols = [row[0] for row in columns if row[1] in ('integer','bigint','numeric','double precision','real','smallint','decimal')]

    found = False

    if text_cols:
        where = ' OR '.join([f"{col}::text ILIKE %s" for col in text_cols])
        query = sql.SQL('SELECT 1 FROM {} WHERE ' + where + ' LIMIT 1').format(sql.Identifier(table))
        cur.execute(query, tuple(['%' + search_value + '%'] * len(text_cols)))
        if cur.fetchone():
            matches.append((table, 'text'))
            continue

    if numeric_cols:
        where = ' OR '.join([f"{col} = %s" for col in numeric_cols])
        query = sql.SQL('SELECT 1 FROM {} WHERE ' + where + ' LIMIT 1').format(sql.Identifier(table))
        cur.execute(query, tuple([int(search_value)] * len(numeric_cols)))
        if cur.fetchone():
            matches.append((table, 'numeric'))

print(matches)

cur.close()
conn.close()
