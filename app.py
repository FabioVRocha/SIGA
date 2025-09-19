# Importa as classes e funções necessárias do Flask
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
# Importa o módulo para conectar ao PostgreSQL
import psycopg2
# Importa o módulo para lidar com erros de banco de dados
from psycopg2 import Error
from psycopg2.errors import UndefinedColumn
import datetime # Para formatar datas
import calendar  # Para cálculo de dias úteis
from functools import wraps # Para criar um decorador de login
# Importa as funções para hashing de senhas
from werkzeug.security import generate_password_hash, check_password_hash
import re # Para expressões regulares, usado para parsear rgcdes
import json # Para lidar com dados JSON (para parâmetros de usuário)

# Importa as configurações do arquivo config.py
from config import DB_HOST, DB_NAME, DB_USER, DB_PASS, DB_PORT, SECRET_KEY, SYSTEM_VERSION, LOGGED_IN_USER, SIGA_DB_NAME, USER_PARAMETERS_TABLE

# Inicializa a aplicação Flask
app = Flask(__name__)
# Define a chave secreta importada do config.py
app.secret_key = SECRET_KEY

AVAILABLE_PARAMETER_REPORTS = [
    ('report_revenue_comparison', 'Comparativo de Faturamento'),
    ('report_revenue_by_cfop', 'Faturamento por CFOP'),
    ('report_revenue_by_line', 'Faturamento por Linha'),
    ('report_average_price', 'Preço Médio'),
    ('report_revenue_by_day', 'Faturamento por Dia'),
    ('report_revenue_by_state', 'Faturamento por Estado'),
    ('report_revenue_by_vendor', 'Faturamento por Vendedor'),
    ('invoices_mirror', 'Espelho de Notas Fiscais Faturadas'),
]


def format_currency_brl(value):
    """Formata valores numéricos no padrão de moeda brasileira."""
    try:
        value = float(value)
    except (TypeError, ValueError):
        value = 0.0
    return f"R$ {value:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def format_decimal_br(value, decimals=2):
    """Formata valores numéricos no padrão brasileiro com casas decimais configuráveis."""
    try:
        value = float(value)
    except (TypeError, ValueError):
        value = 0.0
    format_pattern = f"{{:,.{decimals}f}}"
    return format_pattern.format(value).replace(",", "X").replace(".", ",").replace("X", ".")


app.jinja_env.filters["format_currency_brl"] = format_currency_brl
app.jinja_env.filters["format_decimal_br"] = format_decimal_br

def count_business_days(year, months=None):
    """Calcula o número de dias úteis (segunda a sexta) para o ano e meses informados."""
    total = 0
    months = months or range(1, 13)
    for m in months:
        try:
            _, days_in_month = calendar.monthrange(year, m)
        except calendar.IllegalMonthError:
            continue
        for day in range(1, days_in_month + 1):
            if datetime.date(year, m, day).weekday() < 5:
                total += 1
    return total

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
    except (Error, UnicodeDecodeError) as e:
        print(f"Erro ao conectar ao banco de dados PostgreSQL do ERP: {e}")
        # flash(f"Erro ao conectar ao banco de dados do ERP: {e}", "danger") # Removido flash em função de conexão
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
    except (Error, UnicodeDecodeError) as e:
        print(f"Erro ao conectar ao banco de dados auxiliar SIGA_DB: {e}")
        # flash(f"Erro ao conectar ao banco de dados auxiliar: {e}", "danger") # Removido flash em função de conexão
        return None

def init_siga_db():
    """
    Inicializa o banco de dados auxiliar, criando a tabela de usuários e parâmetros se elas não existirem.
    """
    conn = get_siga_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            # Cria a tabela de usuários
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username VARCHAR(80) UNIQUE NOT NULL,
                    password_hash VARCHAR(128) NOT NULL
                );
            """)
            # Cria a tabela de parâmetros de usuário
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {USER_PARAMETERS_TABLE} (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    param_name VARCHAR(100) NOT NULL,
                    param_value TEXT,
                    UNIQUE(user_id, param_name),
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                );
            """)
            conn.commit()
            cur.close()
            print("Tabelas 'users' e 'user_parameters' verificadas/criadas com sucesso no siga_db.")
        except Error as e:
            print(f"Erro ao inicializar o siga_db: {e}")
            # flash(f"Erro ao inicializar o banco de dados auxiliar: {e}", "danger") # Removido flash em init_siga_db
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
        # Em um ambiente de produção, você também verificaria a validade da sessão, etc.
    return decorated_function

def get_user_parameters(user_id, param_name):
    """
    Busca um parâmetro específico para um usuário.
    Retorna o valor do parâmetro ou None se não encontrado.
    """
    conn = get_siga_db_connection()
    param_value = None
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(f"SELECT param_value FROM {USER_PARAMETERS_TABLE} WHERE user_id = %s AND param_name = %s", (user_id, param_name))
            result = cur.fetchone()
            if result:
                param_value = result[0]
            cur.close()
        except Error as e:
            print(f"Erro ao buscar parâmetro '{param_name}' para o usuário {user_id}: {e}")
            # flash(f"Erro ao buscar parâmetro: {e}", "danger") # Removido flash em get_user_parameters
        finally:
            if conn:
                conn.close()
    return param_value

def save_user_parameters(user_id, param_name, param_value):
    """
    Salva ou atualiza um parâmetro para um usuário.
    """
    conn = get_siga_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            # Tenta atualizar o registro existente
            update_query = (
                f"UPDATE {USER_PARAMETERS_TABLE} SET param_value = %s "
                "WHERE user_id = %s AND param_name = %s"
            )
            cur.execute(update_query, (param_value, user_id, param_name))

            # Se nenhuma linha foi atualizada, insere um novo registro
            if cur.rowcount == 0:
                insert_query = (
                    f"INSERT INTO {USER_PARAMETERS_TABLE} "
                    "(user_id, param_name, param_value) VALUES (%s, %s, %s)"
                )
                cur.execute(insert_query, (user_id, param_name, param_value))

            conn.commit()
            cur.close()
            return True
        except Error as e:
            print(f"Erro ao salvar parâmetro '{param_name}' para o usuário {user_id}: {e}")
            flash(f"Erro ao salvar parâmetros: {e}", "danger") # Manter flash aqui, pois ocorre em contexto de requisição
            return False
        finally:
            if conn:
                conn.close()
    return False


def parse_transaction_signs(signs_str):
    """Converte string de sinais ('123:+,456:-') em dicionário."""
    signs = {}
    if signs_str:
        for item in signs_str.split(','):
            if ':' in item:
                code, sign = item.split(':', 1)
                code = code.strip()
                sign = sign.strip()
                if sign not in ['+', '-']:
                    sign = '+'
                signs[code] = sign
    return signs


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
                    session['user_id'] = user[0] # Armazena o ID do usuário na sessão
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

def get_distinct_states():
    """Busca todos os estados distintos presentes no ERP."""
    conn = get_erp_db_connection()
    states = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT DISTINCT estado FROM cidade ORDER BY estado;")
            states = [row[0] for row in cur.fetchall() if row[0]]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar estados distintos: {e}')
        finally:
            conn.close()
    return states

def get_distinct_cities():
    """Busca todas as cidades distintas presentes no ERP."""
    conn = get_erp_db_connection()
    cities = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT DISTINCT cidnome FROM cidade ORDER BY cidnome;")
            cities = [row[0] for row in cur.fetchall() if row[0]]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar cidades distintas: {e}')
        finally:
            conn.close()
    return cities

def get_distinct_vendors():
    """Busca todos os vendedores distintos e seus status presentes no ERP."""
    conn = get_erp_db_connection()
    vendors = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT DISTINCT vennome, venstatus FROM vendedor ORDER BY vennome;"
            )
            vendors = [
                (row[0], row[1]) for row in cur.fetchall() if row[0]
            ]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar vendedores distintos: {e}')
        finally:
            conn.close()
    return vendors


def get_distinct_vendor_statuses():
    """Busca todos os status de vendedores distintos presentes no ERP."""
    conn = get_erp_db_connection()
    statuses = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT DISTINCT venstatus FROM vendedor ORDER BY venstatus;"
            )
            statuses = [row[0] for row in cur.fetchall() if row[0]]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar status de vendedores: {e}')
        finally:
            conn.close()
    return statuses

def fetch_monthly_revenue(year, filters):
    """Retorna o faturamento mensal para o ano especificado.

    Esta função executa uma consulta agregada no ERP e pode aplicar
    filtros opcionais de mês, estado, cidade, vendedor, linha de produto e CFOP.
    """
    conn = get_erp_db_connection()
    monthly_totals = [0.0] * 12

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_comparison'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}

            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT EXTRACT(MONTH FROM tm.pridata) AS mes,
                       SUM(tm.privltotal) AS total,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                LEFT JOIN vendedor v ON d.vennome = v.vennome
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [year]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue

                if valid_months:
                    placeholders = ','.join(['%s'] * len(valid_months))
                    sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                    params.extend(valid_months)
            states = filters.get('state')
            if states:
                placeholders = ','.join(['%s'] * len(states))
                sql += f' AND c.estado IN ({placeholders})'
                params.extend(states)

            cities = filters.get('city')
            if cities:
                placeholders = ','.join(['%s'] * len(cities))
                sql += f" AND c.cidnome IN ({placeholders})"
                params.extend(cities)

            vendors = filters.get('vendor')
            if vendors:
                placeholders = ','.join(['%s'] * len(vendors))
                sql += f" AND d.vennome IN ({placeholders})"
                params.extend(vendors)

            vendor_statuses = filters.get('vendor_status')
            if vendor_statuses:
                placeholders = ','.join(['%s'] * len(vendor_statuses))
                sql += f" AND v.venstatus IN ({placeholders})"
                params.extend(vendor_statuses)

            lines = filters.get('line')
            if lines:
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) in lines:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)
            # Quando nenhum parametro de transacao e definido pelo usuario o
            # filtro nao e aplicado para permitir a exibicao de dados

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY mes, op.opetransac ORDER BY mes"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            for mes, total, transac in results:
                idx = int(mes) - 1
                sign = transaction_signs.get(str(transac), '+')
                if sign == '-':
                    monthly_totals[idx] -= float(total)
                else:
                    monthly_totals[idx] += float(total)
            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento mensal: {e}')
        finally:
            conn.close()

    return monthly_totals


def fetch_all_cfops():
    """Retorna todas as CFOPs cadastradas."""
    conn = get_erp_db_connection()
    cfops = []
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT operacao FROM opera ORDER BY operacao;")
            cfops = [str(row[0]).strip() for row in cur.fetchall() if row and row[0]]
            cur.close()
        except Error as e:
            print(f'Erro ao buscar CFOPs: {e}')
        finally:
            conn.close()
    return cfops


def fetch_revenue_by_cfop(filters):
    """Retorna o faturamento agregado por CFOP."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_by_cfop'

            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}

            selected_cfops_str = get_user_parameters(
                user_id, 'report_revenue_by_cfop_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT op.operacao,
                       SUM(tm.privltotal + tm.privlipi + tm.privlsubst) AS valor_bruto,
                       SUM(tm.privlipi) AS valor_ipi,
                       SUM(tm.privlsubst) AS valor_st,
                       SUM(tm.privltotal) AS valor_liquido,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [filters.get('year')]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue
                if valid_months:
                    if len(valid_months) == 1:
                        sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                        params.append(valid_months[0])
                    else:
                        placeholders = ','.join(['%s'] * len(valid_months))
                        sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                        params.extend(valid_months)

            if filters.get('state'):
                sql += ' AND c.estado = %s'
                params.append(filters['state'])
            if filters.get('city'):
                sql += " AND c.cidnome = %s"
                params.append(filters['city'])
            if filters.get('vendor'):
                sql += " AND d.vennome = %s"
                params.append(filters['vendor'])

            if filters.get('line'):
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) == filters['line']:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY op.operacao, op.opetransac ORDER BY op.operacao"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            for cfop, bruto, ipi, st, liquido, transac in results:
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                data.append({
                    'cfop': cfop,
                    'valor_bruto': float(bruto or 0) * mult,
                    'valor_ipi': float(ipi or 0) * mult,
                    'valor_st': float(st or 0) * mult,
                    'valor_liquido': float(liquido or 0) * mult
                })
            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento por CFOP: {e}')
        finally:
            conn.close()

    return data


def fetch_revenue_by_line(filters):
    """Retorna o faturamento agregado por linha de produto."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_by_line'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}
            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT g.grunome,
                       SUM(tm.privltotal) AS valor_liquido,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [filters.get('year')]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue
                if valid_months:
                    if len(valid_months) == 1:
                        sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                        params.append(valid_months[0])
                    else:
                        placeholders = ','.join(['%s'] * len(valid_months))
                        sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                        params.extend(valid_months)

            if filters.get('state'):
                sql += ' AND c.estado = %s'
                params.append(filters['state'])
            if filters.get('city'):
                sql += " AND c.cidnnome = %s"
                params.append(filters['city'])
            if filters.get('vendor'):
                sql += " AND d.vennome = %s"
                params.append(filters['vendor'])

            if filters.get('line'):
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) == filters['line']:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY g.grunome, op.opetransac"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            line_totals = {}
            for group_name, liquido, transac in results:
                line = get_product_line(group_name)
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                line_totals[line] = line_totals.get(line, 0.0) + float(liquido or 0) * mult

            for line, total in line_totals.items():
                data.append({'line': line, 'valor_liquido': total})

            data.sort(key=lambda x: x['line'])
            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento por linha: {e}')
        finally:
            conn.close()

    return data


def fetch_average_price(filters):
    """Retorna o preço médio por linha e mês/ano."""
    conn = get_erp_db_connection()
    chart_labels = []
    chart_datasets = []
    treemap_data = []
    line_colors = {}

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_average_price'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}
            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT g.grunome,
                       TO_CHAR(tm.pridata, 'MM/YYYY') AS mes_ano,
                       SUM(tm.privltotal) AS valor,
                       SUM(tm.priquanti) AS quantidade,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [filters.get('year')]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue
                if valid_months:
                    if len(valid_months) == 1:
                        sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                        params.append(valid_months[0])
                    else:
                        placeholders = ','.join(['%s'] * len(valid_months))
                        sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                        params.extend(valid_months)

            if filters.get('state'):
                sql += ' AND c.estado = %s'
                params.append(filters['state'])
            if filters.get('city'):
                sql += " AND c.cidnnome = %s"
                params.append(filters['city'])
            if filters.get('vendor'):
                sql += " AND d.vennome = %s"
                params.append(filters['vendor'])

            if filters.get('line'):
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) == filters['line']:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY g.grunome, mes_ano, op.opetransac"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()

            line_month_totals = {}
            line_totals = {}
            all_months = set()
            for group_name, mes_ano, valor, quantidade, transac in results:
                line = get_product_line(group_name)
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                valor = float(valor or 0) * mult
                quantidade = float(quantidade or 0) * mult
                lm = line_month_totals.setdefault(line, {}).setdefault(mes_ano, {'valor': 0, 'quantidade': 0})
                lm['valor'] += valor
                lm['quantidade'] += quantidade
                lt = line_totals.setdefault(line, {'valor': 0, 'quantidade': 0})
                lt['valor'] += valor
                lt['quantidade'] += quantidade
                all_months.add(mes_ano)

            sorted_months = sorted(all_months, key=lambda x: datetime.datetime.strptime(x, '%m/%Y'))
            chart_labels = sorted_months

            color_palette = [
                '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
                '#FF9F40', '#C9CBCF', '#7FC97F', '#FDC086', '#386CB0'
            ]

            for idx, (line, months_data) in enumerate(line_month_totals.items()):
                data_points = []
                for m in sorted_months:
                    sums = months_data.get(m)
                    if sums and sums['quantidade'] != 0:
                        data_points.append(sums['valor'] / sums['quantidade'])
                    else:
                        data_points.append(0)
                color = color_palette[idx % len(color_palette)]
                chart_datasets.append({
                    'label': line,
                    'data': data_points,
                    'fill': True,
                    'borderColor': color,
                    'backgroundColor': f"{color}33"
                })
                line_colors[line] = color

            for line, totals in line_totals.items():
                avg = totals['valor'] / totals['quantidade'] if totals['quantidade'] else 0
                treemap_data.append({'x': line, 'v': avg})

            cur.close()
        except Error as e:
            print(f'Erro ao buscar preço médio: {e}')
        finally:
            conn.close()

    return chart_labels, chart_datasets, treemap_data, line_colors


def fetch_revenue_by_day(filters):
    """Retorna o faturamento agregado por dia."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_by_day'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}
            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT EXTRACT(DAY FROM tm.pridata) AS day,
                       SUM(tm.privltotal) AS valor_liquido,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE EXTRACT(YEAR FROM tm.pridata) = %s
            """
            params = [filters.get('year')]

            months = filters.get('month')
            if months:
                month_tokens = months if isinstance(months, list) else [months]
                valid_months = []
                for m in month_tokens:
                    try:
                        valid_months.append(int(m))
                    except ValueError:
                        continue
                if valid_months:
                    if len(valid_months) == 1:
                        sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                        params.append(valid_months[0])
                    else:
                        placeholders = ','.join(['%s'] * len(valid_months))
                        sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                        params.extend(valid_months)

            states = filters.get('state')
            if states:
                placeholders = ','.join(['%s'] * len(states))
                sql += f' AND c.estado IN ({placeholders})'
                params.extend(states)
            cities = filters.get('city')
            if cities:
                placeholders = ','.join(['%s'] * len(cities))
                sql += f" AND c.cidnome IN ({placeholders})"
                params.extend(cities)
            vendors = filters.get('vendor')
            if vendors:
                placeholders = ','.join(['%s'] * len(vendors))
                sql += f" AND d.vennome IN ({placeholders})"
                params.extend(vendors)

            lines = filters.get('line')
            if lines:
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) in lines:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += " GROUP BY EXTRACT(DAY FROM tm.pridata), op.opetransac"

            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            day_totals = {}
            for day, liquido, transac in results:
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                day_key = int(day)
                day_totals[day_key] = day_totals.get(day_key, 0.0) + float(liquido or 0) * mult

            for day_key in sorted(day_totals.keys()):
                data.append({'day': day_key, 'valor_liquido': day_totals[day_key]})

            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento por dia: {e}')
        finally:
            conn.close()

    return data


def fetch_revenue_by_state(filters):
    """Retorna o faturamento agregado por estado."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            cur = conn.cursor()

            user_id = session.get('user_id')
            report_id = 'report_revenue_by_state'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}

            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            sql = """
                SELECT c.estado AS uf,
                       SUM(tm.privltotal) AS valor_liquido,
                       op.opetransac
                FROM doctos d
                LEFT JOIN empresa e ON d.notclifor = e.empresa
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                LEFT JOIN opera op ON d.operacao = op.operacao
                WHERE 1=1
            """
            params = []

            if filters.get('start_date'):
                sql += " AND tm.pridata >= %s"
                params.append(filters['start_date'])
            if filters.get('end_date'):
                sql += " AND tm.pridata <= %s"
                params.append(filters['end_date'])

            if not filters.get('start_date') and not filters.get('end_date'):
                sql += " AND EXTRACT(YEAR FROM tm.pridata) = %s"
                params.append(filters.get('year'))

                months = filters.get('month')
                if months:
                    month_tokens = months if isinstance(months, list) else [months]
                    valid_months = []
                    for m in month_tokens:
                        try:
                            valid_months.append(int(m))
                        except ValueError:
                            continue
                    if valid_months:
                        if len(valid_months) == 1:
                            sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                            params.append(valid_months[0])
                        else:
                            placeholders = ','.join(['%s'] * len(valid_months))
                            sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                            params.extend(valid_months)

            if filters.get('state'):
                sql += ' AND c.estado = %s'
                params.append(filters['state'])
            if filters.get('city'):
                sql += " AND c.cidnome = %s"
                params.append(filters['city'])
            if filters.get('vendor'):
                sql += " AND d.vennome = %s"
                params.append(filters['vendor'])

            if filters.get('line'):
                matching_group_codes = []
                temp_conn = get_erp_db_connection()
                if temp_conn:
                    try:
                        temp_cur = temp_conn.cursor()
                        temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                        groups_data = temp_cur.fetchall()
                        temp_cur.close()
                        for code, name in groups_data:
                            if get_product_line(name) == filters['line']:
                                matching_group_codes.append(code)
                    except Error as e:
                        print(f'Erro ao buscar grupos para filtro de linha: {e}')
                    finally:
                        temp_conn.close()
                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    sql += f" AND g.grupo IN ({placeholders})"
                    params.extend(matching_group_codes)
                else:
                    sql += " AND FALSE"

            if selected_transactions:
                placeholders = ','.join(['%s'] * len(selected_transactions))
                sql += f" AND op.opetransac IN ({placeholders})"
                params.extend(selected_transactions)

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                sql += f" AND op.operacao IN ({placeholders})"
                params.extend(selected_cfops)

            sql += ' GROUP BY c.estado, op.opetransac'


            cur.execute(sql, tuple(params))
            results = cur.fetchall()
            state_totals = {}
            for uf, liquido, transac in results:
                sign = transaction_signs.get(str(transac), '+')
                mult = -1 if sign == '-' else 1
                state_key = uf or 'N/D'
                state_totals[state_key] = state_totals.get(state_key, 0.0) + float(liquido or 0) * mult

            for state, total in state_totals.items():
                data.append({'state': state, 'valor_liquido': total})

            data.sort(key=lambda x: x['state'])
            cur.close()
        except Error as e:
            print(f'Erro ao buscar faturamento por estado: {e}')
        finally:
            conn.close()

    return data

def fetch_revenue_by_vendor(filters):
    """Retorna o faturamento agregado por vendedor."""
    conn = get_erp_db_connection()
    data = []

    if conn:
        try:
            user_id = session.get('user_id')
            report_id = 'report_revenue_by_vendor'
            transaction_signs = parse_transaction_signs(
                get_user_parameters(user_id, f'{report_id}_invoice_transaction_signs')
            )
            selected_transactions = list(transaction_signs.keys())
            if not selected_transactions:
                selected_transactions_str = get_user_parameters(
                    user_id, f'{report_id}_selected_invoice_transactions'
                )
                if selected_transactions_str:
                    selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
                    transaction_signs = {t: '+' for t in selected_transactions}
            selected_cfops_str = get_user_parameters(
                user_id, f'{report_id}_selected_report_cfops'
            )
            selected_cfops = []
            if selected_cfops_str:
                selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

            try:
                cur = conn.cursor()
                sql = """
                        SELECT COALESCE(v.vennome, 'Sem Vendedor') AS vennome,
                               SUM(tm.privltotal) AS valor_liquido,
                               op.opetransac
                        FROM doctos d
                        LEFT JOIN empresa e ON d.notclifor = e.empresa
                        LEFT JOIN cidade c ON d.noscidade = c.cidade
                        LEFT JOIN toqmovi tm ON d.controle = tm.itecontrol
                        LEFT JOIN ntvped1 np ON np.ntvnota = d.controle
                        LEFT JOIN comnf cf ON d.notdocto = cf.comncontr::text
                        LEFT JOIN vendedor v ON cf.comnvende = v.vendedor
                        LEFT JOIN produto p ON tm.priproduto = p.produto
                        LEFT JOIN grupo g ON p.grupo = g.grupo
                        LEFT JOIN opera op ON d.operacao = op.operacao
                        WHERE EXTRACT(YEAR FROM tm.pridata) = %s
                """
                params = [filters.get('year')]

                months = filters.get('month')
                if months:
                    month_tokens = months if isinstance(months, list) else [months]
                    valid_months = []
                    for m in month_tokens:
                        try:
                            valid_months.append(int(m))
                        except ValueError:
                            continue
                    if valid_months:
                        if len(valid_months) == 1:
                            sql += " AND EXTRACT(MONTH FROM tm.pridata) = %s"
                            params.append(valid_months[0])    
                        else:
                            placeholders = ','.join(['%s'] * len(valid_months))
                            sql += f" AND EXTRACT(MONTH FROM tm.pridata) IN ({placeholders})"
                            params.extend(valid_months)

                if filters.get('state'):
                    sql += ' AND c.estado = %s'
                    params.append(filters['state'])
                if filters.get('city'):
                    sql += " AND c.cidnome = %s"
                    params.append(filters['city'])
                if filters.get('vendor'):
                    sql += " AND d.vennome = %s"
                    params.append(filters['vendor'])

                if filters.get('line'):
                    matching_group_codes = []
                    temp_conn = get_erp_db_connection()
                    if temp_conn:
                        try:
                            temp_cur = temp_conn.cursor()
                            temp_cur.execute("SELECT grupo, grunome FROM grupo;")
                            groups_data = temp_cur.fetchall()
                            temp_cur.close()
                            for code, name in groups_data:
                                if get_product_line(name) == filters['line']:
                                    matching_group_codes.append(code)
                        except Error as e:
                            print(f'Erro ao buscar grupos para filtro de linha: {e}')
                        finally:
                            temp_conn.close()
                    if matching_group_codes:
                        placeholders = ','.join(['%s'] * len(matching_group_codes))
                        sql += f" AND g.grupo IN ({placeholders})"
                        params.extend(matching_group_codes)
                    else:
                        sql += " AND FALSE"

                if selected_transactions:
                    placeholders = ','.join(['%s'] * len(selected_transactions))
                    sql += f" AND op.opetransac IN ({placeholders})"
                    params.extend(selected_transactions)
                if selected_cfops:
                    placeholders = ','.join(['%s'] * len(selected_cfops))
                    sql += f" AND op.operacao IN ({placeholders})"
                    params.extend(selected_cfops)
                sql += " GROUP BY COALESCE(v.vennome, 'Sem Vendedor'), op.opetransac"

                cur.execute(sql, tuple(params))
                results = cur.fetchall()
                vendor_totals = {}
                for name, liquido, transac in results:
                    vendor = name
                    sign = transaction_signs.get(str(transac), '+')
                    mult = -1 if sign == '-' else 1
                    vendor_totals[vendor] = vendor_totals.get(vendor, 0.0) + float(liquido or 0) * mult

                for vendor, total in vendor_totals.items():
                    data.append({'vendor': vendor, 'valor_liquido': total})

                data.sort(key=lambda x: x['vendor'])
                cur.close()
            except UndefinedColumn:
                conn.rollback()
                cur.close()
                data.clear()
        except Error as e:
            print(f'Erro ao buscar faturamento por vendedor: {e}')
        finally:
            conn.close()

    return data

def parse_regcar_description(rgcdes_string):
    """
    Parses the rgcdes string to extract freight percentages and M³ value.
    Replicates the Power Query M script logic.
    Example: "P0.05;M0.03;G0.02;#0.01;V0.04;S0.06;$1.2"
    """
    data = {
        'P': 0.0, 'M': 0.0, 'G': 0.0, '#': 0.0, 'V': 0.0, 'S': 0.0, 'M3': 0.0
    }
    if not rgcdes_string:
        return data

    # Substitui vírgulas por pontos para garantir a conversão correta para float
    rgcdes_string = rgcdes_string.replace(',', '.')

    # Use regex to find patterns like [LETTER][NUMBER]; or $[NUMBER]
    patterns = {
        'P': r"P([\d.]+)(?:;|$)",
        'M': r"M([\d.]+)(?:;|$)",
        'G': r"G([\d.]+)(?:;|$)",
        '#': r"#([\d.]+)(?:;|$)",
        'V': r"V([\d.]+)(?:;|$)",
        'S': r"S([\d.]+)(?:;|$)",
        'M3': r"\$([\d.]+)"
    }

    for key, pattern in patterns.items():
        match = re.search(pattern, rgcdes_string)
        if match:
            try:
                value = float(match.group(1))
                data[key] = value
            except ValueError:
                pass # If conversion to float fails, keep default 0.0
    return data

def calculate_freight_percentage(product_line, product_ref, regcar_parsed_data):
    """
    Calculates the freight percentage based on product line, product reference,
    and parsed regcar data, replicating the DAX formula.
    """
    if not regcar_parsed_data:
        return 0.0

    product_ref_upper = product_ref.upper() if product_ref else ""

    print(f"Calculating freight: Line='{product_line}', Ref='{product_ref_upper}', RegcarData={regcar_parsed_data}") # DEBUG

    if product_line == "MADRESILVA":
        return regcar_parsed_data.get('M', 0.0)
    elif product_line == "PETRA":
        return regcar_parsed_data.get('P', 0.0)
    elif product_line == "SOLARE":
        return regcar_parsed_data.get('S', 0.0)
    elif product_line == "GLASSMADRE":
        return regcar_parsed_data.get('V', 0.0)
    elif product_line == "GARLAND":
        if product_ref_upper in ["SF", "NM", "RC", "CH", "SC"]:
            return regcar_parsed_data.get('G', 0.0)
        elif product_ref_upper in ["PF", "PT", "AL", "MA", "MC"]:
            return regcar_parsed_data.get('#', 0.0)
    print(f"No matching freight rule, returning 0.0") # DEBUG
    return 0.0 # Default if no condition matches

def calculate_invoice_freight(controle):
    """Calcula o percentual e o valor de frete de uma nota fiscal com base
    nos itens da nota."""
    conn = get_erp_db_connection()
    total_produtos = 0.0
    total_frete = 0.0
    freight_percentage = 0.0

    if conn:
        try:
            cur = conn.cursor()

            # Recupera o rgcdes da nota para calcular o frete
            cur.execute(
                """
                SELECT COALESCE(rc.rgcdes, '')
                FROM doctos d
                LEFT JOIN cidade c ON d.noscidade = c.cidade
                LEFT JOIN regcar rc ON c.rgccicod = rc.rgccod
                WHERE d.controle = %s
                """,
                (controle,)
            )
            rgcdes_row = cur.fetchone()
            rgcdes = rgcdes_row[0] if rgcdes_row else ''
            regcar_data = parse_regcar_description(rgcdes)

            # Busca os itens da nota
            cur.execute(
                """
                SELECT tm.privltotal, p.pronome, g.grunome
                FROM toqmovi tm
                JOIN produto p ON tm.priproduto = p.produto
                LEFT JOIN grupo g ON p.grupo = g.grupo
                WHERE tm.itecontrol = %s
                """,
                (controle,),
            )
            items = cur.fetchall()

            for privltotal, pronome, grunome in items:
                item_valor = float(privltotal or 0.0)
                product_line = get_product_line(grunome)
                product_ref = pronome[:2] if pronome else ''
                perc_item = calculate_freight_percentage(
                    product_line, product_ref, regcar_data
                )
                total_frete += perc_item * item_valor
                total_produtos += item_valor

            if total_produtos:
                freight_percentage = (total_frete / total_produtos) * 100
        except Error as e:
            print(f"Erro ao calcular frete da nota {controle}: {e}")
        finally:
            conn.close()

    return freight_percentage, total_frete

@app.route('/invoices_mirror')
@login_required
def invoices_mirror():
    """
    Rota que exibe o espelho das notas fiscais faturadas com filtros.
    """
    conn = get_erp_db_connection() # Conecta ao DB do ERP
    invoices_data = []  # Para armazenar os dados processados
    totals_summary = {
        'valor_produtos': 0.0,
        'valor_ipi': 0.0,
        'valor_st': 0.0,
        'valor_total': 0.0,
        'valor_frete': 0.0
    }

    # Get current date for default filter values
    today = datetime.date.today().isoformat() # Format as YYYY-MM-DD for HTML input type="date"

    # Initialize filters dictionary
    filters = {
        'start_date': request.args.get('start_date'),
        'end_date': request.args.get('end_date'),
        'client_name': request.args.get('client_name'),
        'document_number': request.args.get('document_number'),
        'lotecar_code': request.args.get('lotecar_code'),
        'product_line': request.args.get('product_line')
    }

    # If no date filters are provided, set them to today's date
    if not filters['start_date'] and not filters['end_date']:
        filters['start_date'] = today
        filters['end_date'] = today

    # Get distinct product lines for the filter combobox
    product_lines = get_distinct_product_lines()

    # Obter transações selecionadas pelo usuário
    user_id = session.get('user_id')
    transaction_signs = parse_transaction_signs(
        get_user_parameters(user_id, 'invoices_mirror_invoice_transaction_signs')
    )
    selected_transactions = list(transaction_signs.keys())
    if not selected_transactions:
        selected_transactions_str = get_user_parameters(
            user_id, 'invoices_mirror_selected_invoice_transactions'
        )
        if selected_transactions_str:
            selected_transactions = [t.strip() for t in selected_transactions_str.split(',') if t.strip()]
            transaction_signs = {t: '+' for t in selected_transactions}
    if selected_transactions:
        print(f"DEBUG: Transações selecionadas para o usuário {user_id}: {selected_transactions}")

    selected_cfops_str = get_user_parameters(
        user_id, 'invoices_mirror_selected_report_cfops'
    )
    selected_cfops = []
    if selected_cfops_str:
        selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

    if conn:
        try:
            cur = conn.cursor()
            # Base SQL query
            sql_query = """
                SELECT
                    d.controle,
                    d.notdocto,
                    d.notdata,
                    d.notvltotal,
                    e.empnome AS client_name,
                    d.notvlipi,
                    COALESCE(SUM(tm.privltotal), 0) AS total_privltotal,
                    COALESCE(SUM(tm.privlsubst), 0) AS total_privlsubst,
                    COALESCE(MAX(rc.rgcdes), '') AS rgcdes_agg,
                    COALESCE(MAX(p.pronome), '') AS pronome_agg,
                    COALESCE(MAX(g.grunome), '') AS grunome_agg,
                    op.opetransac
                FROM
                    doctos d
                JOIN
                    empresa e ON d.notclifor = e.empresa
                LEFT JOIN
                    lotecar lc ON d.vollcacod = lc.lcacod
                LEFT JOIN
                    toqmovi tm ON d.controle = tm.itecontrol
                LEFT JOIN
                    cidade c ON d.noscidade = c.cidade
                LEFT JOIN
                    regcar rc ON c.rgccicod = rc.rgccod
                LEFT JOIN
                    produto p ON tm.priproduto = p.produto
                LEFT JOIN
                    grupo g ON p.grupo = g.grupo
                LEFT JOIN
                    opera op ON d.operacao = op.operacao
            """
            query_params = []
            where_clauses = []

            if filters['start_date']:
                where_clauses.append("tm.pridata >= %s")
                query_params.append(filters['start_date'])
            if filters['end_date']:
                where_clauses.append("tm.pridata <= %s")
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
            
            # Filtro por linha de produto
            if filters['product_line']:
                matching_group_codes = []
                temp_conn_for_groups = get_erp_db_connection()
                if temp_conn_for_groups:
                    try:
                        temp_cur_for_groups = temp_conn_for_groups.cursor()
                        temp_cur_for_groups.execute("SELECT grupo, grunome FROM grupo;")
                        all_groups_data = temp_cur_for_groups.fetchall()
                        temp_cur_for_groups.close()
                        for group_code, group_name in all_groups_data:
                            if get_product_line(group_name) == filters['product_line']:
                                matching_group_codes.append(group_code)
                    except Error as e:
                        print(f"Erro ao buscar grupos para filtro de linha de produto: {e}")
                    finally:
                        if temp_conn_for_groups:
                            temp_conn_for_groups.close()

                if matching_group_codes:
                    placeholders = ','.join(['%s'] * len(matching_group_codes))
                    where_clauses.append(f"g.grupo IN ({placeholders})")
                    query_params.extend(matching_group_codes)
                else:
                    where_clauses.append("FALSE")
            
            # Novo filtro por transações selecionadas
            if selected_transactions:
                # Mantém as transações como strings para corresponder ao tipo da coluna
                valid_transactions = [t for t in selected_transactions if t]
                if valid_transactions:
                    placeholders = ','.join(['%s'] * len(valid_transactions))
                    where_clauses.append(f"op.opetransac IN ({placeholders})")
                    query_params.extend(valid_transactions)
                else:
                    where_clauses.append("FALSE")

            if selected_cfops:
                placeholders = ','.join(['%s'] * len(selected_cfops))
                where_clauses.append(f"op.operacao IN ({placeholders})")
                query_params.extend(selected_cfops)

            if where_clauses:
                sql_query += " WHERE " + " AND ".join(where_clauses)

            sql_query += """
                GROUP BY
                    d.controle, d.notdocto, d.notdata, d.notvltotal, e.empnome,
                    d.notvlipi, op.opetransac
            """
            sql_query += " ORDER BY d.notdata DESC, d.controle DESC;"

            cur.execute(sql_query, tuple(query_params))
            raw_invoices = cur.fetchall()
            cur.close()

            for row in raw_invoices:
                invoice = {
                    'controle': row[0],
                    'notdocto': row[1],
                    'notdata': row[2],
                    'notvltotal': row[3],
                    'client_name': row[4],
                    'notvlipi': row[5],
                    'total_privltotal': row[6], # Valor Produtos
                    'total_privlsubst': row[7], # Valor ST
                    'rgcdes': row[8], # rgcdes_agg
                    'pronome': row[9], # pronome_agg
                    'grunome': row[10], # grunome_agg
                    'operacao': row[11] # Código da transação
                }
                print(
                    f"Processing invoice {invoice['controle']}: rgcdes='{invoice['rgcdes']}', pronome='{invoice['pronome']}', grunome='{invoice['grunome']}'"
                )  # DEBUG

                freight_percentage, valor_frete = calculate_invoice_freight(invoice['controle'])

                invoice['freight_percentage'] = freight_percentage
                invoice['valor_frete'] = valor_frete

                invoices_data.append(invoice)

                # Acumula totais para o rodapé
                sign = transaction_signs.get(str(invoice['operacao']), '+')
                multiplier = -1 if sign == '-' else 1
                totals_summary['valor_produtos'] += multiplier * float(invoice['total_privltotal'] or 0)
                totals_summary['valor_ipi'] += multiplier * float(invoice['notvlipi'] or 0)
                totals_summary['valor_st'] += multiplier * float(invoice['total_privlsubst'] or 0)
                totals_summary['valor_total'] += multiplier * float(invoice['notvltotal'] or 0)
                totals_summary['valor_frete'] += multiplier * float(invoice['valor_frete'] or 0)

        except Error as e:
            print(f"Erro ao executar a consulta: {e}")
            flash(f"Erro ao carregar notas fiscais: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template(
        'invoices_mirror.html',
        invoices=invoices_data,
        filters=filters,
        product_lines=product_lines,
        totals=totals_summary,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

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

@app.route('/api/get_invoice_details/<int:controle>')
@login_required
def get_invoice_details(controle):
    """
    Rota de API para buscar detalhes de uma nota fiscal específica (cabeçalho e itens).
    """
    print(f"DEBUG: get_invoice_details called for controle: {controle}") # DEBUG
    conn = get_erp_db_connection()
    invoice_header = {}
    invoice_items = []
    
    if conn:
        try:
            cur = conn.cursor()

            # Buscar dados do cabeçalho da nota fiscal
            cur.execute("""
                SELECT
                    d.notdocto,
                    d.notclifor,
                    e.empnome,
                    op.opetransac,
                    d.notdata,
                    d.notvltotal,
                    COALESCE(rc.rgcdes, '') AS rgcdes
                FROM
                    doctos d
                JOIN
                    empresa e ON d.notclifor = e.empresa
                LEFT JOIN
                    opera op ON d.operacao = op.operacao
                LEFT JOIN
                    cidade c ON d.noscidade = c.cidade
                LEFT JOIN
                    regcar rc ON c.rgccicod = rc.rgccod
                WHERE
                    d.controle = %s
            """, (controle,))
            header_data = cur.fetchone()
            print(f"DEBUG: Header data for controle {controle}: {header_data}") # DEBUG
            if header_data:
                invoice_header = {
                    'notdocto': header_data[0],
                    'notclifor': header_data[1],
                    'empnome': header_data[2],
                    'operacao': header_data[3],  # Código da transação
                    'notdata': header_data[4].strftime('%d/%m/%Y') if header_data[4] else 'N/A',
                    'notvltotal': float(header_data[5]) if header_data[5] is not None else 0.0,
                    'rgcdes': header_data[6]
                }

            # Buscar itens de produto da nota fiscal
            cur.execute("""
                SELECT
                    tm.prisequen,
                    tm.priproduto,
                    p.pronome,
                    p.unimedida,
                    tm.priquanti,
                    tm.pritmpuni,
                    tm.privltotal,
                    tm.prialqipi,
                    tm.privlipi,
                    tm.privlsubst,
                    COALESCE(g.grunome, '') AS grunome
                FROM
                    toqmovi tm
                JOIN
                    produto p ON tm.priproduto = p.produto
                LEFT JOIN
                    grupo g ON p.grupo = g.grupo
                WHERE
                    tm.itecontrol = %s
                ORDER BY
                    tm.prisequen
            """, (controle,))
            items_data = cur.fetchall()
            print(f"DEBUG: Items data for controle {controle}: {items_data}") # DEBUG

            regcar_data = parse_regcar_description(invoice_header.get('rgcdes', ''))

            for item in items_data:
                item_privltotal = item[6] if item[6] is not None else 0
                item_privlipi = item[8] if item[8] is not None else 0
                item_privlsubst = item[9] if item[9] is not None else 0
                
                valor_total_item = item_privltotal + item_privlipi + item_privlsubst

                product_line = get_product_line(item[10])
                product_ref = item[2][:2] if item[2] else ""
                freight_pct = calculate_freight_percentage(product_line, product_ref, regcar_data)

                freight_percentage_display = freight_pct * 100
                valor_frete_item = (freight_percentage_display / 100) * float(item_privltotal)

                invoice_items.append({
                    'prisequen': item[0],
                    'priproduto': item[1],
                    'pronome': item[2],
                    'unimedida': item[3],
                    'priquanti': float(item[4]) if item[4] is not None else 0.0,
                    'pritmpuni': float(item[5]) if item[5] is not None else 0.0,
                    'privltotal': float(item_privltotal),
                    'prialqipi': float(item[7]) if item[7] is not None else 0.0,
                    'privlipi': float(item_privlipi),
                    'privlsubst': float(item_privlsubst),
                    'valor_total_item': float(valor_total_item),
                    'freight_percentage': freight_percentage_display,
                    'valor_frete': valor_frete_item
                })
            cur.close()

        except Error as e:
            print(f"ERRO ao buscar detalhes da nota fiscal no backend: {e}") # DEBUG
            return jsonify({'error': str(e)}), 500
        finally:
            if conn:
                conn.close()
    
    print(f"DEBUG: Returning details for controle {controle}: Header={invoice_header}, Items count={len(invoice_items)}") # DEBUG
    return jsonify({
        'header': invoice_header,
        'items': invoice_items
    })

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



def fetch_production_lots():
    """Retorna os lotes de producao disponiveis para o filtro."""
    lots = []
    conn = get_erp_db_connection()

    if not conn:
        return lots

    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT lotcod, COALESCE(lotdes, '')
            FROM loteprod
            WHERE lotcod IS NOT NULL
            ORDER BY lotcod DESC
            """
        )
        rows = cur.fetchall()
        cur.close()

        for lotcod, lotdes in rows:
            if lotcod is None:
                continue
            value = str(lotcod)
            label = value if not lotdes else f"{value} - {lotdes}"
            lots.append({'value': value, 'label': label})
    except Error as e:
        print(f"Erro ao carregar lotes de producao: {e}")
    finally:
        if conn:
            conn.close()

    return lots

def fetch_orders(filters):
    """Busca os pedidos com agregações de quantidade, reservas, separações e carregamentos."""
    orders = []
    error_message = None
    conn = get_erp_db_connection()

    if not conn:
        return orders, "Não foi possível conectar ao banco de dados do ERP."

    has_lcacod_column = False
    column_check_cursor = None

    try:
        column_check_cursor = conn.cursor()
        column_check_cursor.execute(
            """
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_name = 'pedido'
                  AND column_name = 'lcacod'
            )
            """
        )
        result = column_check_cursor.fetchone()
        if result:
            has_lcacod_column = result[0]
    except Error as e:
        print(f"Erro ao verificar a coluna 'lcacod' na tabela 'pedido': {e}")
    finally:
        if column_check_cursor:
            column_check_cursor.close()

    try:
        cur = conn.cursor()
        query = """
            WITH prod_quant AS (
                SELECT pedido, SUM(COALESCE(pprquanti, 0)) AS total_quantidade
                FROM pedprodu
                GROUP BY pedido
            ),
            proj_totals AS (
                SELECT prjmpedid AS pedido,
                       SUM(CASE WHEN prjmovtip = 'R' THEN COALESCE(prjmquant, 0) ELSE 0 END) AS reservado,
                       SUM(CASE WHEN prjmovtip = 'P' THEN COALESCE(prjmquant, 0) ELSE 0 END) AS separado,
                       SUM(CASE WHEN prjmovtip = 'C' THEN COALESCE(prjmquant, 0) ELSE 0 END) AS carregado
                FROM projmovi
                GROUP BY prjmpedid
            ),
            linha_info AS (
                SELECT ordped AS pedido,
                       STRING_AGG(linha_value, ', ') AS linha
                FROM (
                    SELECT DISTINCT o.ordped, COALESCE(lp.lotdes, lp.lotcod::text) AS linha_value
                    FROM ordem o
                    LEFT JOIN loteprod lp ON o.lotcod = lp.lotcod
                    WHERE o.ordped IS NOT NULL
                          AND COALESCE(lp.lotdes, lp.lotcod::text) IS NOT NULL
                ) sub
                GROUP BY ordped
            )
            SELECT
                p.pedido,
                p.lcaseque,
                p.pedcliente,
                COALESCE(e.empnome, '') AS empnome,
                CASE
                    WHEN COALESCE(c.cidnome, '') <> '' AND COALESCE(c.estado, '') <> '' THEN c.cidnome || '/' || c.estado
                    WHEN COALESCE(c.cidnome, '') <> '' THEN c.cidnome
                    WHEN COALESCE(c.estado, '') <> '' THEN c.estado
                    WHEN COALESCE(p.pedentcid::text, '') <> '' AND COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentcid::text || '/' || p.pedentuf::text
                    WHEN COALESCE(p.pedentcid::text, '') <> '' THEN p.pedentcid::text
                    WHEN COALESCE(p.pedentuf::text, '') <> '' THEN p.pedentuf::text
                    ELSE ''
                END AS cidade_uf,
                COALESCE(prod.total_quantidade, 0) AS quantidade_total,
                COALESCE(proj.reservado, 0) AS reservado,
                COALESCE(proj.separado, 0) AS separado,
                COALESCE(proj.carregado, 0) AS carregado,
                COALESCE(linha.linha, '') AS linha
            FROM pedido p
            LEFT JOIN empresa e ON p.pedcliente = e.empresa
            LEFT JOIN cidade c ON p.pedentcid = c.cidade
            LEFT JOIN prod_quant prod ON p.pedido = prod.pedido
            LEFT JOIN proj_totals proj ON p.pedido = proj.pedido
            LEFT JOIN linha_info linha ON p.pedido = linha.pedido
        """
        if has_lcacod_column:
            query += "            LEFT JOIN lotecar lc ON p.lcacod = lc.lcacod\n"
        query += "            WHERE 1 = 1\n"

        params = []

        if filters.get('order_number'):
            query += " AND CAST(p.pedido AS TEXT) ILIKE %s"
            params.append(f"%{filters['order_number']}%")

        if filters.get('client_code'):
            query += " AND CAST(p.pedcliente AS TEXT) ILIKE %s"
            params.append(f"%{filters['client_code']}%")

        if filters.get('client_name'):
            query += " AND COALESCE(e.empnome, '') ILIKE %s"
            params.append(f"%{filters['client_name']}%")

        if filters.get('city'):
            query += " AND COALESCE(c.cidnome, '') ILIKE %s"
            params.append(f"%{filters['city']}%")

        if filters.get('state'):
            query += " AND COALESCE(c.estado, '') ILIKE %s"
            params.append(f"%{filters['state']}%")

        if filters.get('load_lot'):
            if has_lcacod_column:
                query += " AND (CAST(p.lcacod AS TEXT) ILIKE %s OR COALESCE(lc.lcades, '') ILIKE %s)"
                params.append(f"%{filters['load_lot']}%")
                params.append(f"%{filters['load_lot']}%")
            else:
                print("Coluna 'lcacod' ausente na tabela 'pedido'; filtro 'Lote de Carga' foi ignorado.")

        if filters.get('production_lot'):
            query += """
                AND EXISTS (
                    SELECT 1
                    FROM ordem o
                    LEFT JOIN loteprod lp ON o.lotcod = lp.lotcod
                    WHERE o.ordped = p.pedido
                      AND (CAST(o.lotcod AS TEXT) ILIKE %s OR COALESCE(lp.lotdes, '') ILIKE %s)
                )
            """
            params.append(f"%{filters['production_lot']}%")
            params.append(f"%{filters['production_lot']}%")

        if filters.get('line'):
            query += " AND COALESCE(linha.linha, '') ILIKE %s"
            params.append(f"%{filters['line']}%")

        if filters.get('start_date'):
            try:
                start_date = datetime.datetime.strptime(filters['start_date'], '%Y-%m-%d').date()
                query += " AND p.peddata >= %s"
                params.append(start_date)
            except ValueError:
                pass

        if filters.get('end_date'):
            try:
                end_date = datetime.datetime.strptime(filters['end_date'], '%Y-%m-%d').date()
                query += " AND p.peddata <= %s"
                params.append(end_date)
            except ValueError:
                pass

        query += " ORDER BY p.pedido DESC"

        cur.execute(query, tuple(params))
        rows = cur.fetchall()
        cur.close()

        for row in rows:
            orders.append({
                'pedido': row[0],
                'sequencia_lote': row[1],
                'cliente_codigo': row[2],
                'cliente_nome': row[3],
                'cidade_uf': row[4],
                'quantidade_total': float(row[5]) if row[5] is not None else 0.0,
                'reservado': float(row[6]) if row[6] is not None else 0.0,
                'separado': float(row[7]) if row[7] is not None else 0.0,
                'carregado': float(row[8]) if row[8] is not None else 0.0,
                'linha': row[9]
            })

    except Error as e:
        print(f"Erro ao carregar pedidos: {e}")
        error_message = f"Erro ao carregar pedidos: {e}"
    finally:
        if conn:
            conn.close()

    return orders, error_message


@app.route('/orders_list')
@login_required
def orders_list():
    today = datetime.date.today()
    first_day_of_month = today.replace(day=1)
    last_day_of_month = first_day_of_month.replace(
        day=calendar.monthrange(today.year, today.month)[1]
    )

    def _clean_filter_arg(arg_name: str) -> str:
        value = request.args.get(arg_name)
        return value.strip() if value else ''

    filters_for_display = {
        'order_number': _clean_filter_arg('order_number'),
        'client_code': _clean_filter_arg('client_code'),
        'client_name': _clean_filter_arg('client_name'),
        'city': _clean_filter_arg('city'),
        'state': _clean_filter_arg('state'),
        'load_lot': _clean_filter_arg('load_lot'),
        'production_lot': _clean_filter_arg('production_lot'),
        'line': _clean_filter_arg('line'),
        'start_date': _clean_filter_arg('start_date'),
        'end_date': _clean_filter_arg('end_date'),
    }

    filters_for_query = {
        key: (value or None)
        for key, value in filters_for_display.items()
    }

    has_non_date_filters = any(
        filters_for_query[key]
        for key in (
            'order_number',
            'client_code',
            'client_name',
            'city',
            'state',
            'load_lot',
            'production_lot',
            'line',
        )
    )
    has_explicit_date_filters = (
        filters_for_query['start_date'] is not None
        or filters_for_query['end_date'] is not None
    )

    if not has_non_date_filters and not has_explicit_date_filters:
        filters_for_query['start_date'] = first_day_of_month.strftime('%Y-%m-%d')
        filters_for_query['end_date'] = last_day_of_month.strftime('%Y-%m-%d')

    applied_start_date = filters_for_query['start_date']
    applied_end_date = filters_for_query['end_date']

    orders, error_message = fetch_orders(filters_for_query)

    production_lots = fetch_production_lots()

    if error_message:
        flash(error_message, 'danger')

    totals = {
        'quantidade_total': sum(order['quantidade_total'] for order in orders),
        'reservado': sum(order['reservado'] for order in orders),
        'separado': sum(order['separado'] for order in orders),
        'carregado': sum(order['carregado'] for order in orders),
    }

    return render_template(
        'orders_list.html',
        orders=orders,
        filters=filters_for_display,
        totals=totals,
        production_lots=production_lots,
        applied_start_date=applied_start_date,
        applied_end_date=applied_end_date,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

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
@app.route('/report_revenue_by_cfop')
@login_required
def report_revenue_by_cfop():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    data = fetch_revenue_by_cfop(filters)
    totals = {
        'valor_bruto': sum(row['valor_bruto'] for row in data),
        'valor_ipi': sum(row['valor_ipi'] for row in data),
        'valor_st': sum(row['valor_st'] for row in data),
        'valor_liquido': sum(row['valor_liquido'] for row in data)
    }
    return render_template(
        'report_revenue_by_cfop.html',
        data=data,
        filters=filters,
        totals=totals,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_sales_by_product')
@login_required
def report_sales_by_product():
    return render_template(
        'placeholder.html',
        page_title="Relatório: Vendas por Produto",
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_customer_sales')
@login_required
def report_customer_sales():
    return render_template(
        'placeholder.html',
        page_title="Relatório: Vendas por Cliente",
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_revenue_by_state')
@login_required
def report_revenue_by_state():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'start_date': request.args.get('start_date'),
        'end_date': request.args.get('end_date'),
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    data = fetch_revenue_by_state(filters)
    chart_labels = [row['state'] for row in data]
    chart_values = [row['valor_liquido'] for row in data]
    total_liquido = sum(chart_values)
    return render_template(
        'report_revenue_by_state.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_liquido=total_liquido,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_revenue_by_line')
@login_required
def report_revenue_by_line():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    data = fetch_revenue_by_line(filters)
    chart_labels = [row['line'] for row in data]
    chart_values = [row['valor_liquido'] for row in data]
    total_liquido = sum(chart_values)
    return render_template(
        'report_revenue_by_line.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_liquido=total_liquido,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


@app.route('/report_average_price')
@login_required
def report_average_price():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    chart_labels, chart_datasets, treemap_data, line_colors = fetch_average_price(filters)
    return render_template(
        'report_average_price.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_datasets=chart_datasets,
        treemap_data=treemap_data,
        line_colors=line_colors,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_revenue_by_day')
@login_required
def report_revenue_by_day():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.getlist('state'),
        'city': request.args.getlist('city'),
        'vendor': request.args.getlist('vendor'),
        'line': request.args.getlist('line')
    }
    data = fetch_revenue_by_day(filters)
    chart_labels = [row['day'] for row in data]
    chart_values = [row['valor_liquido'] for row in data]
    total_liquido = sum(chart_values)
    months_selected = set()
    if filters['month']:
        for m in filters['month']:
            try:
                months_selected.add(int(m))
            except ValueError:
                continue
    else:
        months_selected = set(range(1, 13))
    business_days = count_business_days(current_year, months_selected)
    daily_average = total_liquido / business_days if business_days else 0
    return render_template(
        'report_revenue_by_day.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_liquido=total_liquido,
        daily_average=daily_average,
        states=get_distinct_states(),
        cities=get_distinct_cities(),
        vendors=get_distinct_vendors(),
        product_lines=get_distinct_product_lines(),
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

@app.route('/report_revenue_by_vendor')
@login_required
def report_revenue_by_vendor():
    current_year = int(request.args.get('year', datetime.date.today().year))
    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.get('state'),
        'city': request.args.get('city'),
        'vendor': request.args.get('vendor'),
        'line': request.args.get('line')
    }
    data = fetch_revenue_by_vendor(filters)
    chart_labels = [row['vendor'] for row in data]
    chart_values = [row['valor_liquido'] for row in data]
    total_liquido = sum(chart_values)
    return render_template(
        'report_revenue_by_vendor.html',
        filters=filters,
        chart_labels=chart_labels,
        chart_values=chart_values,
        total_liquido=total_liquido,
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )

# Página intermediária para relatórios de faturamento
@app.route('/revenue_reports')
@login_required
def revenue_reports():
    """Página de seleção dos relatórios de faturamento."""
    return render_template('revenue_reports.html', page_title="Relatórios de Faturamento", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/report_revenue_comparison')
@login_required
def report_revenue_comparison():
    """Exibe um comparativo de faturamento anual (ano atual x ano anterior)."""

    current_year = int(request.args.get('year', datetime.date.today().year))

    vendor_status = request.args.getlist('vendor_status')
    if not request.args.get('filter_applied') and not vendor_status:
        vendor_status = ['A']

    filters = {
        'year': current_year,
        'month': request.args.getlist('month'),
        'state': request.args.getlist('state'),
        'city': request.args.getlist('city'),
        'vendor': request.args.getlist('vendor'),
        'vendor_status': vendor_status,
        'line': request.args.getlist('line')
    }

    data_filters = filters.copy()
    data_filters.pop('vendor_status', None)

    prev_year = current_year - 1
    current_data_all = fetch_monthly_revenue(current_year, data_filters)
    prev_filters = data_filters.copy()
    previous_data_all = fetch_monthly_revenue(prev_year, prev_filters)

    months_selected = [int(m) for m in filters['month']] if filters['month'] else list(range(1,13))
    labels = [f"{str(m).zfill(2)}/{current_year}" for m in months_selected]
    current_data = [current_data_all[m-1] for m in months_selected]
    previous_data = [previous_data_all[m-1] for m in months_selected]

    current_total = sum(current_data)
    previous_total = sum(previous_data)
    totals = {
        'current_total': current_total,
        'current_average': current_total / len(months_selected) if months_selected else 0,
        'previous_total': previous_total,
        'previous_average': previous_total / len(months_selected) if months_selected else 0,
        'variation_percent': ((current_total - previous_total) / previous_total * 100) if previous_total else 0
    }

    return render_template(
        'report_revenue_comparison.html',
        chart_labels=labels,
        current_year_data=current_data,
        previous_year_data=previous_data,
        current_year_label=str(current_year),
        previous_year_label=str(prev_year),
        totals=totals,
        filters=filters,
        states=get_distinct_states(),
        cities=get_distinct_cities(),
        vendors=get_distinct_vendors(),
        vendor_statuses=get_distinct_vendor_statuses(),
        product_lines=get_distinct_product_lines(),
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado')
    )


# --- Rotas de Placeholder para o Menu (Gerencial) ---
@app.route('/backup_db')
@login_required
def backup_db():
    """Rota placeholder para backup do banco de dados."""
    return render_template('placeholder.html', page_title="Backup do Banco de Dados", system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

@app.route('/gerencial/parameters', methods=['GET', 'POST'])
@login_required
def gerencial_parameters():
    """
    Rota para a tela de parâmetros do sistema.
    Permite ao usuário selecionar transações que devem ser apresentadas no Espelho de Notas Fiscais.
    """
    user_id = session.get('user_id')

    available_reports = AVAILABLE_PARAMETER_REPORTS
    report_ids = [r[0] for r in available_reports]
    selected_report = request.form.get('report') if request.method == 'POST' else request.args.get('report')
    if selected_report not in report_ids:
        selected_report = available_reports[0][0]
    
    conn_erp = get_erp_db_connection()
    all_transactions = []
    all_cfops = []
    if conn_erp:
        try:
            cur_erp = conn_erp.cursor()
            cur_erp.execute("SELECT transacao, trsnome FROM transa ORDER BY trsnome;")
            # Ensure transacao values are stored as strings to match form inputs
            all_transactions = [{'transacao': str(t[0]), 'trsnome': t[1]} for t in cur_erp.fetchall()]
            
            cur_erp.execute("SELECT operacao FROM opera ORDER BY operacao;")
            all_cfops = [str(row[0]).strip() for row in cur_erp.fetchall() if row and row[0]]

            cur_erp.close()
        except Error as e:
            print(f"Erro ao buscar transações ou CFOPs: {e}")
            flash(f"Erro ao carregar transações ou CFOPs: {e}", "danger")
        finally:
            if conn_erp:
                conn_erp.close()

    if request.method == 'POST':
        selected_transactions = request.form.getlist('selected_transactions')
        selected_transactions_str = ','.join(selected_transactions)
        
        transaction_signs = {}
        for trans in selected_transactions:
            sign = request.form.get(f'sign_{trans}', '+')
            if sign not in ['+', '-']:
                sign = '+'
            transaction_signs[trans] = sign
        transaction_signs_str = ','.join(f'{t}:{s}' for t, s in transaction_signs.items())

        selected_cfops = [c.strip() for c in request.form.getlist('selected_cfops')]
        selected_cfops_str = ','.join(selected_cfops)

        success = True
        if not save_user_parameters(user_id, f'{selected_report}_selected_invoice_transactions', selected_transactions_str):
            success = False
        if not save_user_parameters(user_id, f'{selected_report}_invoice_transaction_signs', transaction_signs_str):
            success = False
        if not save_user_parameters(user_id, f'{selected_report}_selected_report_cfops', selected_cfops_str):
            success = False
        if success:
            flash('Parâmetros de transação e CFOP salvos com sucesso!', 'success')
        else:
            flash('Falha ao salvar parâmetros de transação ou CFOP.', 'danger')
        return redirect(url_for('gerencial_parameters', report=selected_report))
    
    # GET request: Load current selected transactions and signs
    current_signs_str = get_user_parameters(user_id, f'{selected_report}_invoice_transaction_signs')
    current_transaction_signs = parse_transaction_signs(current_signs_str)
    current_selected_transactions = list(current_transaction_signs.keys())
    if not current_selected_transactions:
        current_selected_transactions_str = get_user_parameters(user_id, f'{selected_report}_selected_invoice_transactions')
        if current_selected_transactions_str:
            current_selected_transactions = [t.strip() for t in current_selected_transactions_str.split(',') if t.strip()]
            current_transaction_signs = {t: '+' for t in current_selected_transactions}

    selected_cfops_str = get_user_parameters(user_id, f'{selected_report}_selected_report_cfops')
    current_selected_cfops = []
    if selected_cfops_str:
        current_selected_cfops = [c.strip() for c in selected_cfops_str.split(',') if c.strip()]

    # Marcar as transações e CFOPs que já estão selecionados
    for trans in all_transactions:
        code = trans['transacao']
        trans['is_selected'] = code in current_selected_transactions
        trans['sign'] = current_transaction_signs.get(code, '+')

    cfops_data = []
    for cfop in all_cfops:
        cfops_data.append({'cfop': cfop, 'is_selected': cfop in current_selected_cfops})

    return render_template(
        'parameters.html',
        page_title="Parâmetros do Sistema",
        system_version=SYSTEM_VERSION,
        usuario_logado=session.get('username', 'Convidado'),
        all_transactions=all_transactions,
        all_cfops=cfops_data,
        available_reports=available_reports,
        selected_report=selected_report
    )


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
    session.pop('user_id', None) # Limpa o user_id também
    flash('Você foi desconectado.', 'info')
    return redirect(url_for('login'))

# Adiciona um print para depuração do mapa de URLs
if __name__ == '__main__':
    print("Flask URL Map:")
    for rule in app.url_map.iter_rules():
        print(f"Endpoint: {rule.endpoint}, Methods: {rule.methods}, Rule: {rule.rule}")
    app.run(host="0.0.0.0", port=5001, debug=True)
