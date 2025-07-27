# Importa as classes e funções necessárias do Flask
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
# Importa o módulo para conectar ao PostgreSQL
import psycopg2
# Importa o módulo para lidar com erros de banco de dados
from psycopg2 import Error
import datetime # Para formatar datas
from functools import wraps # Para criar um decorador de login
# Importa as funções para hashing de senhas
from werkzeug.security import generate_password_hash, check_password_hash

# Importa as configurações do arquivo config.py
from config import DB_HOST, DB_NAME, DB_USER, DB_PASS, DB_PORT, SECRET_KEY, SYSTEM_VERSION, LOGGED_IN_USER, SIGA_DB_NAME

# Inicializa a aplicação Flask
app = Flask(__name__)
# Define a chave secreta importada do config.py
app.secret_key = SECRET_KEY

def get_erp_db_connection():
    """
    Estabelece e retorna uma conexão com o banco de dados PostgreSQL do ERP.
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
        print(f"Erro ao conectar ao banco de dados PostgreSQL do ERP: {e}")
        flash(f"Erro ao conectar ao banco de dados do ERP: {e}", "danger")
        return None

def get_siga_db_connection():
    """
    Estabelece e retorna uma conexão com o banco de dados PostgreSQL auxiliar (siga_db).
    """
    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST, # Assume o mesmo host do ERP, mas com DB diferente
            database=SIGA_DB_NAME,
            user=DB_USER, # Assume o mesmo usuário do ERP, mas pode ser diferente
            password=DB_PASS, # Assume a mesma senha do ERP, mas pode ser diferente
            port=DB_PORT
        )
        return conn
    except Error as e:
        print(f"Erro ao conectar ao banco de dados auxiliar SIGA_DB: {e}")
        flash(f"Erro ao conectar ao banco de dados auxiliar: {e}", "danger")
        return None

def init_siga_db():
    """
    Inicializa o banco de dados auxiliar, criando a tabela de usuários se ela não existir.
    """
    conn = get_siga_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(80) UNIQUE NOT NULL,
                    password_hash VARCHAR(128) NOT NULL
                );
            """)
            conn.commit()
            cur.close()
            print("Tabela 'users' verificada/criada com sucesso no siga_db.")
        except Error as e:
            print(f"Erro ao inicializar o siga_db: {e}")
            flash(f"Erro ao inicializar o banco de dados auxiliar: {e}", "danger")
        finally:
            if conn:
                conn.close()

# Chama a função de inicialização do banco de dados auxiliar ao iniciar a aplicação
with app.app_context():
    init_siga_db()

def login_required(f):
    """
    Decorador para proteger rotas, exigindo que o usuário esteja logado.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            flash('Você precisa fazer login para acessar esta página.', 'danger')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/login', methods=['GET', 'POST'])
def login():
    """
    Rota para a tela de login.
    Lida com a exibição do formulário e o processamento da autenticação.
    """
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        conn = get_siga_db_connection()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("SELECT id, username, password_hash FROM users WHERE username = %s", (username,))
                user = cur.fetchone()
                cur.close()
                conn.close()

                if user and check_password_hash(user[2], password): # user[2] é o password_hash
                    session['logged_in'] = True
                    session['username'] = user[1] # user[1] é o username
                    flash('Login realizado com sucesso!', 'success')
                    return redirect(url_for('dashboard'))
                else:
                    flash('Usuário ou senha inválidos.', 'danger')
            except Error as e:
                print(f"Erro ao autenticar usuário: {e}")
                flash(f"Erro ao autenticar: {e}", "danger")
            finally:
                if conn:
                    conn.close()
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    """
    Rota para o cadastro de novos usuários.
    """
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        confirm_password = request.form['confirm_password']

        if not username or not password or not confirm_password:
            flash('Todos os campos são obrigatórios.', 'warning')
            return render_template('register.html')

        if password != confirm_password:
            flash('As senhas não coincidem.', 'danger')
            return render_template('register.html')

        hashed_password = generate_password_hash(password)

        conn = get_siga_db_connection()
        if conn:
            try:
                cur = conn.cursor()
                cur.execute("INSERT INTO users (username, password_hash) VALUES (%s, %s)", (username, hashed_password))
                conn.commit()
                cur.close()
                flash('Usuário cadastrado com sucesso! Faça login para continuar.', 'success')
                return redirect(url_for('login'))
            except psycopg2.IntegrityError: # Erro de violação de unicidade (username já existe)
                flash('Nome de usuário já existe. Por favor, escolha outro.', 'danger')
            except Error as e:
                print(f"Erro ao cadastrar usuário: {e}")
                flash(f"Erro ao cadastrar usuário: {e}", "danger")
            finally:
                if conn:
                    conn.close()
    return render_template('register.html')

@app.route('/')
def home():
    """
    Rota inicial que redireciona para o dashboard se logado, ou para o login.
    """
    if 'logged_in' in session:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    """
    Rota para o dashboard principal do sistema.
    """
    return render_template('dashboard.html', system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

def get_product_line(group_name):
    """
    Função para determinar a linha de produto com base no nome do grupo,
    replicando a lógica DAX fornecida.
    """
    group_name_upper = group_name.upper() if group_name else ""

    if "MADRESILVA" in group_name_upper or "* M." in group_name_upper:
        return "MADRESILVA"
    elif "PETRA" in group_name_upper or "* P." in group_name_upper:
        return "PETRA"
    elif "GARLAND" in group_name_upper or "* G." in group_name_upper:
        return "GARLAND"
    elif "GLASS" in group_name_upper or "* V." in group_name_upper:
        return "GLASSMADRE"
    elif "CAVILHAS" in group_name_upper:
        return "CAVILHAS"
    elif "SOLARE" in group_name_upper or "* S." in group_name_upper:
        return "SOLARE"
    elif "ESPUMA" in group_name_upper or "* ESPUMA" in group_name_upper:
        return "ESPUMA"
    else:
        return "OUTROS"

def get_distinct_product_lines():
    """
    Busca todas as linhas de produto distintas do ERP.
    """
    conn = get_erp_db_connection()
    product_lines = set()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT grunome FROM grupo;")
            group_names = cur.fetchall()
            cur.close()
            for name_tuple in group_names:
                product_lines.add(get_product_line(name_tuple[0]))
        except Error as e:
            print(f"Erro ao buscar linhas de produto distintas: {e}")
        finally:
            if conn:
                conn.close()
    return sorted(list(product_lines))


@app.route('/invoices_mirror')
@login_required
def invoices_mirror():
    """
    Rota que exibe o espelho das notas fiscais faturadas com filtros.
    """
    conn = get_erp_db_connection() # Conecta ao DB do ERP
    invoices = []

    # Get current date for default filter values
    today = datetime.date.today().isoformat() # Format as YYYY-MM-DD for HTML input type="date"

    # Initialize filters dictionary
    filters = {
        'start_date': request.args.get('start_date'),
        'end_date': request.args.get('end_date'),
        'client_name': request.args.get('client_name'),
        'document_number': request.args.get('document_number'),
        'lotecar_code': request.args.get('lotecar_code'),
        'product_line': request.args.get('product_line') # Novo filtro: linha de produto
    }

    # If no date filters are provided, set them to today's date
    if not filters['start_date'] and not filters['end_date']:
        filters['start_date'] = today
        filters['end_date'] = today

    # Get distinct product lines for the filter combobox
    product_lines = get_distinct_product_lines()

    if conn:
        try:
            cur = conn.cursor()
            # Base SQL query
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
                LEFT JOIN
                    lotecar lc ON d.vollcacod = lc.lcacod
            """
            query_params = []
            where_clauses = []

            if filters['start_date']:
                where_clauses.append("d.notdata >= %s")
                query_params.append(filters['start_date'])
            if filters['end_date']:
                where_clauses.append("d.notdata <= %s")
                query_params.append(filters['end_date'])
            if filters['client_name']:
                where_clauses.append("e.empnome ILIKE %s")
                query_params.append(f"%{filters['client_name']}%")
            if filters['document_number']:
                where_clauses.append("d.notdocto = %s")
                query_params.append(filters['document_number'])
            if filters['lotecar_code']:
                where_clauses.append("lc.lcacod = %s")
                query_params.append(filters['lotecar_code'])
            
            # Adiciona filtro por linha de produto
            if filters['product_line']:
                # Primeiro, encontre todos os códigos de grupo que correspondem à linha de produto selecionada
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        all_groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for group_code, group_name in all_groups_data:
                            if get_product_line(group_name) == filters['product_line']:
                                matching_group_codes.append(group_code)
                    except Error as e:
                        print(f"Erro ao buscar grupos para filtro de linha de produto: {e}")
                    finally:
                        if temp_conn:
                            temp_conn.close()

                if matching_group_codes:
                    # Agora, junte com toqmovi, produto e grupo para filtrar
                    sql_query += """
                        LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                        LEFT JOIN produto p ON tm.priproduto = p.produto
                        LEFT JOIN grupo g ON p.grupo = g.grupo
                    """
                    # Use IN para filtrar pelos códigos de grupo encontrados
                    where_clauses.append("g.grupo IN %s")
                    query_params.append(tuple(matching_group_codes))
                else:
                    # Se nenhuma linha de produto corresponder, retorne um conjunto vazio para não mostrar resultados
                    where_clauses.append("FALSE")


            if where_clauses:
                sql_query += " WHERE " + " AND ".join(where_clauses)

            sql_query += " ORDER BY d.notdata DESC, d.controle DESC;"

            cur.execute(sql_query, tuple(query_params))
            invoices = cur.fetchall()
            cur.close()
        except Error as e:
            print(f"Erro ao executar a consulta: {e}")
            flash(f"Erro ao carregar notas fiscais: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template('invoices_mirror.html', invoices=invoices, filters=filters, product_lines=product_lines, system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/api/get_lotecar_description/<string:lotecar_code>')
@login_required
def get_lotecar_description(lotecar_code):
    """
    Rota de API para buscar a descrição de um lote de carga pelo código.
    """
    conn = get_erp_db_connection()
    description = ""
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT lcades FROM lotecar WHERE lcacod = %s", (lotecar_code,))
            result = cur.fetchone()
            if result:
                description = result[0]
            cur.close()
        except Error as e:
            print(f"Erro ao buscar descrição do lote de carga: {e}")
        finally:
            if conn:
                conn.close()
    return jsonify({'description': description})


@app.route('/api/get_group_product_line/<string:group_name>')
@login_required
def get_group_product_line_api(group_name):
    """
    Rota de API para buscar a linha de produto de um grupo.
    """
    line = get_product_line(group_name)
    return jsonify({'product_line': line})


# --- Rotas de Placeholder para o Menu (Cadastros) ---
@app.route('/companies_list')
@login_required
def companies_list():
    return render_template('placeholder.html', page_title="Lista de Empresas", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/products_list')
@login_required
def products_list():
    return render_template('placeholder.html', page_title="Lista de Produtos", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/vendors_list')
@login_required
def vendors_list():
    return render_template('placeholder.html', page_title="Lista de Vendedores", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/cities_list')
@login_required
def cities_list():
    return render_template('placeholder.html', page_title="Lista de Cidades", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/groups_list')
@login_required
def groups_list():
    """
    Rota para listar os grupos de produto e suas respectivas linhas.
    """
    conn = get_erp_db_connection()
    groups = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT grupo, grunome FROM grupo ORDER BY grunome;")
            raw_groups = cur.fetchall()
            cur.close()

            for group_data in raw_groups:
                group_code = group_data[0]
                group_name = group_data[1]
                product_line = get_product_line(group_name) # Calcula a linha de produto
                groups.append({'grupo': group_code, 'grunome': group_name, 'linha': product_line})

        except Error as e:
            print(f"Erro ao carregar lista de grupos: {e}")
            flash(f"Erro ao carregar grupos: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template('groups_list.html', groups=groups, page_title="Lista de Grupos de Produto", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))


@app.route('/conditions_list')
@login_required
def conditions_list():
    return render_template('placeholder.html', page_title="Lista de Condições de Pagamento", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/operations_list')
@login_required
def operations_list():
    return render_template('placeholder.html', page_title="Lista de Operações", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/transporters_list')
@login_required
def transporters_list():
    return render_template('placeholder.html', page_title="Lista de Transportadoras", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

# --- Rotas de Placeholder para o Menu (Vendas) ---
@app.route('/orders_list')
@login_required
def orders_list():
    return render_template('placeholder.html', page_title="Lista de Pedidos", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/sales_returns_list')
@login_required
def sales_returns_list():
    return render_template('placeholder.html', page_title="Lista de Devoluções de Venda", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

# --- Rotas de Placeholder para o Menu (Financeiro) ---
@app.route('/accounts_receivable_list')
@login_required
def accounts_receivable_list():
    return render_template('placeholder.html', page_title="Contas a Receber", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/accounts_payable_list')
@login_required
def accounts_payable_list():
    return render_template('placeholder.html', page_title="Contas a Pagar", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/titles_list')
@login_required
def titles_list():
    return render_template('placeholder.html', page_title="Lista de Títulos", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/checks_list')
@login_required
def checks_list():
    return render_template('placeholder.html', page_title="Cheques Pré-Datados", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

# --- Rotas de Placeholder para o Menu (Estoque) ---
@app.route('/stock_movements_list')
@login_required
def stock_movements_list():
    return render_template('placeholder.html', page_title="Movimentações de Estoque", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/product_batches_list')
@login_required
def product_batches_list():
    return render_template('placeholder.html', page_title="Lotes de Produto", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

# --- Rotas de Placeholder para o Menu (Relatórios) ---
@app.route('/report_sales_by_product')
@login_required
def report_sales_by_product():
    return render_template('placeholder.html', page_title="Relatório: Vendas por Produto", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/report_customer_sales')
@login_required
def report_customer_sales():
    return render_template('placeholder.html', page_title="Relatório: Vendas por Cliente", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/report_financial_summary')
@login_required
def report_financial_summary():
    return render_template('placeholder.html', page_title="Relatório: Resumo Financeiro", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))


# --- Rotas de Placeholder para o Menu (Gerencial) ---
@app.route('/backup_db')
@login_required
def backup_db():
    return render_template('placeholder.html', page_title="Backup do Banco de Dados", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/users_list')
@login_required
def users_list():
    """
    Rota para listar os usuários cadastrados no siga_db com filtros.
    """
    conn = get_siga_db_connection()
    users = []
    
    filters = {
        'username_filter': request.args.get('username_filter')
    }

    if conn:
        try:
            cur = conn.cursor()
            sql_query = "SELECT id, username FROM users WHERE 1=1"
            query_params = []

            if filters['username_filter']:
                sql_query += " AND username ILIKE %s"
                query_params.append(f"%{filters['username_filter']}%")

            sql_query += " ORDER BY username;"
            
            cur.execute(sql_query, tuple(query_params))
            users = cur.fetchall()
            cur.close()
        except Error as e:
            print(f"Erro ao carregar lista de usuários: {e}")
            flash(f"Erro ao carregar usuários: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template('users_list.html', users=users, filters=filters, page_title="Lista de Usuários", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/logout')
def logout():
    """
    Rota para fazer logout do sistema.
    """
    session.pop('logged_in', None)
    session.pop('username', None)
    flash('Você foi desconectado.', 'info')
    return redirect(url_for('login'))

# Executa a aplicação Flask se o script for o principal
if __name__ == '__main__':
    app.run(debug=True)
