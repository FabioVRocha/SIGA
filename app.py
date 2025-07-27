# Importa as classes e funções necessárias do Flask
from flask import Flask, render_template, request, redirect, url_for, flash
# Importa o módulo para conectar ao PostgreSQL
import psycopg2
# Importa o módulo para lidar com erros de banco de dados
from psycopg2 import Error
import datetime # Para formatar datas

# Inicializa a aplicação Flask
app = Flask(__name__)
# Chave secreta para sessões e mensagens flash (IMPORTANTE: Mude para um valor complexo em produção)
app.secret_key = 'sua_chave_secreta_muito_segura'

# --- Configurações do Banco de Dados PostgreSQL ---
# ATENÇÃO: Substitua estas variáveis com as suas próprias credenciais do banco de dados.
DB_HOST = "localhost"  # Endereço do seu servidor PostgreSQL
DB_NAME = "seu_banco_de_dados"  # Nome do seu banco de dados
DB_USER = "seu_usuario"  # Nome de usuário do PostgreSQL
DB_PASS = "sua_senha"  # Senha do usuário do PostgreSQL
DB_PORT = "5432" # Porta do PostgreSQL (padrão é 5432)

def get_db_connection():
    """
    Estabelece e retorna uma conexão com o banco de dados PostgreSQL.
    """
    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            port=DB_PORT
        )
        return conn
    except Error as e:
        print(f"Erro ao conectar ao banco de dados PostgreSQL: {e}")
        flash(f"Erro ao conectar ao banco de dados: {e}", "danger")
        return None

# Variáveis de exemplo para o rodapé (em um sistema real, viriam de um banco de dados ou configuração)
SYSTEM_VERSION = "1.0.0"
LOGGED_IN_USER = "Admin"

@app.route('/')
@app.route('/dashboard')
def dashboard():
    """
    Rota para o dashboard principal do sistema.
    """
    return render_template('dashboard.html', system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/invoices_mirror')
def invoices_mirror():
    """
    Rota que exibe o espelho das notas fiscais faturadas.
    """
    conn = get_db_connection()
    invoices = []
    if conn:
        try:
            cur = conn.cursor()
            # Consulta SQL para obter o espelho das notas fiscais faturadas.
            # Esta consulta junta as tabelas 'doctos' e 'empresa' para obter
            # os detalhes da nota fiscal e o nome do cliente/fornecedor.
            sql_query = """
                SELECT
                    d.controle,
                    d.notdocto,
                    d.notserie,
                    d.notdata,
                    d.notvltotal,
                    e.empnome AS client_name,
                    d.notcondica,
                    d.notobsfisc,
                    d.notdtalt,
                    d.nothralt,
                    d.notusalt
                FROM
                    doctos d
                JOIN
                    empresa e ON d.notclifor = e.empresa
                ORDER BY
                    d.notdata DESC, d.controle DESC;
            """
            cur.execute(sql_query)
            invoices = cur.fetchall()
            cur.close()
        except Error as e:
            print(f"Erro ao executar a consulta: {e}")
            flash(f"Erro ao carregar notas fiscais: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template('invoices_mirror.html', invoices=invoices, system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

# --- Rotas de Placeholder para o Menu (Cadastros) ---
@app.route('/companies_list')
def companies_list():
    return render_template('placeholder.html', page_title="Lista de Empresas", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/products_list')
def products_list():
    return render_template('placeholder.html', page_title="Lista de Produtos", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/vendors_list')
def vendors_list():
    return render_template('placeholder.html', page_title="Lista de Vendedores", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/cities_list')
def cities_list():
    return render_template('placeholder.html', page_title="Lista de Cidades", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/groups_list')
def groups_list():
    return render_template('placeholder.html', page_title="Lista de Grupos de Produto", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/conditions_list')
def conditions_list():
    return render_template('placeholder.html', page_title="Lista de Condições de Pagamento", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/operations_list')
def operations_list():
    return render_template('placeholder.html', page_title="Lista de Operações", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/transporters_list')
def transporters_list():
    return render_template('placeholder.html', page_title="Lista de Transportadoras", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

# --- Rotas de Placeholder para o Menu (Vendas) ---
@app.route('/orders_list')
def orders_list():
    return render_template('placeholder.html', page_title="Lista de Pedidos", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/sales_returns_list')
def sales_returns_list():
    return render_template('placeholder.html', page_title="Lista de Devoluções de Venda", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

# --- Rotas de Placeholder para o Menu (Financeiro) ---
@app.route('/accounts_receivable_list')
def accounts_receivable_list():
    return render_template('placeholder.html', page_title="Contas a Receber", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/accounts_payable_list')
def accounts_payable_list():
    return render_template('placeholder.html', page_title="Contas a Pagar", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/titles_list')
def titles_list():
    return render_template('placeholder.html', page_title="Lista de Títulos", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/checks_list')
def checks_list():
    return render_template('placeholder.html', page_title="Cheques Pré-Datados", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

# --- Rotas de Placeholder para o Menu (Estoque) ---
@app.route('/stock_movements_list')
def stock_movements_list():
    return render_template('placeholder.html', page_title="Movimentações de Estoque", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/product_batches_list')
def product_batches_list():
    return render_template('placeholder.html', page_title="Lotes de Produto", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

# --- Rotas de Placeholder para o Menu (Relatórios) ---
@app.route('/report_sales_by_product')
def report_sales_by_product():
    return render_template('placeholder.html', page_title="Relatório: Vendas por Produto", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/report_customer_sales')
def report_customer_sales():
    return render_template('placeholder.html', page_title="Relatório: Vendas por Cliente", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/report_financial_summary')
def report_financial_summary():
    return render_template('placeholder.html', page_title="Relatório: Resumo Financeiro", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)


# --- Rotas de Placeholder para o Menu (Gerencial) ---
@app.route('/backup_db')
def backup_db():
    return render_template('placeholder.html', page_title="Backup do Banco de Dados", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/users_list')
def users_list():
    return render_template('placeholder.html', page_title="Lista de Usuários", system_version=SYSTEM_VERSION, usuario_logado=LOGGED_IN_USER)

@app.route('/logout')
def logout():
    flash("Você foi desconectado.", "info")
    return redirect(url_for('dashboard')) # Redireciona para o dashboard ou página de login

# Executa a aplicação Flask se o script for o principal
if __name__ == '__main__':
    app.run(debug=True)
