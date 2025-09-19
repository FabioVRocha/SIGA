import psycopg2, config
conn=psycopg2.connect(host=config.DB_HOST,database=config.DB_NAME,user=config.DB_USER,password=config.DB_PASS,port=config.DB_PORT)
cur=conn.cursor()
cur.execute("SELECT * FROM vw_produto_ordem_producao LIMIT 10")
rows=cur.fetchall()
for row in rows:
    print(row)
cur.close()
conn.close()
