import psycopg2
from psycopg2 import sql

conn = psycopg2.connect(host='45.161.184.156', port=5433, dbname='madresilva', user='postgres', password='postgres')
cur = conn.cursor()

search_value = '002319'
tables = ['toqmovi','pw_pedido_venda','pw_ordem']

for table in tables:
    cur.execute(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema=%s AND table_name=%s",
        ('public', table)
    )
    columns = [row[0] for row in cur.fetchall() if row[1] in ('character varying','character','text','bpchar')]
    matches = []
    for col in columns:
        query = sql.SQL('SELECT DISTINCT {col}::text FROM {table} WHERE {col}::text ILIKE %s LIMIT 5')\
            .format(col=sql.Identifier(col), table=sql.Identifier(table))
        cur.execute(query, ('%' + search_value + '%',))
        values = [row[0].strip() if isinstance(row[0], str) else row[0] for row in cur.fetchall()]
        if values:
            matches.append((col, values))
    if matches:
        print(table)
        for col, vals in matches:
            print(' ', col, vals)

cur.close()
conn.close()
