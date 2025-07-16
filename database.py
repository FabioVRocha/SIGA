# siga_erp/database.py

import psycopg2
from psycopg2 import Error
from config import Config # Importa a classe de configuração

class DBManager:
    """
    Gerencia a conexão e operações com o banco de dados PostgreSQL.
    """
    def __init__(self):
        """
        Inicializa o DBManager com as configurações do banco de dados.
        """
        self.conn = None
        self.cursor = None
        self.db_uri = Config.DATABASE_URI

    def connect(self):
        """
        Estabelece uma conexão com o banco de dados PostgreSQL.
        """
        try:
            self.conn = psycopg2.connect(self.db_uri)
            self.cursor = self.conn.cursor()
            print("Conexão com o banco de dados PostgreSQL estabelecida com sucesso!")
        except Error as e:
            print(f"Erro ao conectar ao banco de dados PostgreSQL: {e}")
            self.conn = None
            self.cursor = None
            raise # Re-lança a exceção para que o chamador possa lidar com ela

    def disconnect(self):
        """
        Fecha a conexão com o banco de dados.
        """
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
            print("Conexão com o banco de dados PostgreSQL fechada.")

    def execute_query(self, query, params=None):
        """
        Executa uma consulta SQL (INSERT, UPDATE, DELETE).
        :param query: A string da consulta SQL.
        :param params: Uma tupla ou lista de parâmetros para a consulta.
        """
        if not self.conn or not self.cursor:
            print("Erro: Conexão com o banco de dados não estabelecida.")
            return False
        try:
            self.cursor.execute(query, params)
            self.conn.commit()
            return True
        except Error as e:
            print(f"Erro ao executar consulta: {e}")
            self.conn.rollback() # Reverte a transação em caso de erro
            return False

    def fetch_all(self, query, params=None):
        """
        Executa uma consulta SQL (SELECT) e retorna todos os resultados.
        :param query: A string da consulta SQL.
        :param params: Uma tupla ou lista de parâmetros para a consulta.
        :return: Uma lista de tuplas contendo os resultados, ou uma lista vazia em caso de erro.
        """
        if not self.conn or not self.cursor:
            print("Erro: Conexão com o banco de dados não estabelecida.")
            return []
        try:
            self.cursor.execute(query, params)
            return self.cursor.fetchall()
        except Error as e:
            print(f"Erro ao buscar dados: {e}")
            return []

    def fetch_one(self, query, params=None):
        """
        Executa uma consulta SQL (SELECT) e retorna um único resultado.
        :param query: A string da consulta SQL.
        :param params: Uma tupla ou lista de parâmetros para a consulta.
        :return: Uma tupla contendo o resultado, ou None em caso de erro ou nenhum resultado.
        """
        if not self.conn or not self.cursor:
            print("Erro: Conexão com o banco de dados não estabelecida.")
            return None
        try:
            self.cursor.execute(query, params)
            return self.cursor.fetchone()
        except Error as e:
            print(f"Erro ao buscar um único dado: {e}")
            return None

