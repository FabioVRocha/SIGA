import psycopg2
from config import DB_HOST, DB_NAME, DB_USER, DB_PASS, DB_PORT
conn = psycopg2.connect(host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS, port=DB_PORT)
try:
    with conn.cursor() as cur:
        cur.execute("SELECT codigo_lote_ordem_producao, codigo_ordem_ordem_producao FROM vw_produto_ordem_producao LIMIT 10")
        for row in cur.fetchall():
            print(row)
finally:
    conn.close()
