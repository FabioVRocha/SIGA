import psycopg2
from psycopg2 import sql

conn = psycopg2.connect(host='45.161.184.156', port=5433, dbname='madresilva', user='postgres', password='postgres')
cur = conn.cursor()

search_value = '002319'
tables = [
    'bcoreme','ceeblk','celprod','compcmaq','etiqdesm','expregis','toqmovi','umagrof','umcomven','umcota','umhisvnd',
    'umnfcomp','umnfoti','umpedfat','umpprodu','umprodca','umrelve1','umrelven','pw_pedido_venda','pw_ordem'
]

results = []

for table in tables:
    cur.execute(
        "SELECT column_name, data_type FROM information_schema.columns WHERE table_schema=%s AND table_name=%s",
        ('public', table)
    )
    columns = [row[0] for row in cur.fetchall() if row[1] in ('character varying','character','text','bpchar')]
    if not columns:
        continue

    where = ' OR '.join([f"{col}::text ILIKE %s" for col in columns])
    query = sql.SQL('SELECT 1 FROM {} WHERE ' + where + ' LIMIT 1').format(sql.Identifier(table))
    cur.execute(query, tuple(['%' + search_value + '%'] * len(columns)))
    if cur.fetchone():
        results.append(table)

print(results)

cur.close()
conn.close()
