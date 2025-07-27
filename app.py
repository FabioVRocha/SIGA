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
import re # Para expressões regulares, usado para parsear rgcdes

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
        if product_ref_upper in ["SF", "NM", "RC", "CH"]:
            return regcar_parsed_data.get('G', 0.0)
        elif product_ref_upper in ["PF", "PT", "AL", "MA", "MC"]:
            return regcar_parsed_data.get('#', 0.0)
    print(f"No matching freight rule, returning 0.0") # DEBUG
    return 0.0 # Default if no condition matches

@app.route('/invoices_mirror')
@login_required
def invoices_mirror():
    """
    Rota que exibe o espelho das notas fiscais faturadas com filtros.
    """
    conn = get_erp_db_connection() # Conecta ao DB do ERP
    invoices_data = [] # Para armazenar os dados processados

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

    if conn:
        try:
            cur = conn.cursor()
            # Base SQL query
            # Ajustado para AGREGAR no nível da nota fiscal
            # COALESCE(MAX(rc.rgcdes), '') garante que rgcdes_agg não seja NULL para parse_regcar_description
            # COALESCE(MAX(p.pronome), '') e COALESCE(MAX(g.grunome), '') para pronome_agg e grunome_agg
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
                    COALESCE(MAX(g.grunome), '') AS grunome_agg
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
            
            # Filtro por linha de produto (agora mais integrado na query principal)
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
                    where_clauses.append("g.grupo IN %s")
                    query_params.append(tuple(matching_group_codes))
                else:
                    where_clauses.append("FALSE")

            if where_clauses:
                sql_query += " WHERE " + " AND ".join(where_clauses)

            # GROUP BY ajustado para agregar por nota fiscal, removendo as colunas agregadas
            sql_query += """
                GROUP BY
                    d.controle, d.notdocto, d.notdata, d.notvltotal, e.empnome,
                    d.notvlipi
            """
            sql_query += " ORDER BY d.notdata DESC, d.controle DESC;"

            cur.execute(sql_query, tuple(query_params))
            raw_invoices = cur.fetchall()
            cur.close()

            # Processar os dados para adicionar o percentual de frete
            for row in raw_invoices:
                # Mapear os campos da query para variáveis nomeadas
                # Os índices aqui devem corresponder à ordem do SELECT
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
                    'grunome': row[10] # grunome_agg
                }
                print(f"Processing invoice {invoice['controle']}: rgcdes='{invoice['rgcdes']}', pronome='{invoice['pronome']}', grunome='{invoice['grunome']}'") # DEBUG

                # Calcular a linha do produto
                product_line = get_product_line(invoice['grunome'])
                
                # Extrair a referência do produto (primeiros 2 caracteres do pronome)
                product_ref = invoice['pronome'][:2] if invoice['pronome'] else ""

                # Parsear a descrição da região de frete
                regcar_data = parse_regcar_description(invoice['rgcdes'])
                print(f"Parsed regcar data: {regcar_data}") # DEBUG

                # Calcular o percentual de frete
                freight_percentage = calculate_freight_percentage(product_line, product_ref, regcar_data)
                print(f"Calculated freight percentage: {freight_percentage}") # DEBUG

                # Adicionar o percentual de frete ao dicionário da fatura
                invoice['freight_percentage'] = freight_percentage * 100 # Multiplicar por 100 para exibir como percentual

                # Calcular o Valor do Frete
                # Converta total_privltotal para float antes da multiplicação
                valor_frete = (invoice['freight_percentage'] / 100) * float(invoice['total_privltotal'] if invoice['total_privltotal'] is not None else 0)
                invoice['valor_frete'] = valor_frete

                invoices_data.append(invoice)

        except Error as e:
            print(f"Erro ao executar a consulta: {e}")
            flash(f"Erro ao carregar notas fiscais: {e}", "danger")
        finally:
            if conn:
                conn.close()
    return render_template('invoices_mirror.html', invoices=invoices_data, filters=filters, product_lines=product_lines, system_version=SYSTEM_VERSION, usuario_logado=session.get('username', 'Convidado'))

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
                    d.operacao,
                    d.notdata,
                    d.notvltotal
                FROM
                    doctos d
                JOIN
                    empresa e ON d.notclifor = e.empresa
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
                    'operacao': header_data[3],
                    'notdata': header_data[4].strftime('%d/%m/%Y') if header_data[4] else 'N/A',
                    'notvltotal': header_data[5]
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
                    tm.privlsubst
                FROM
                    toqmovi tm
                JOIN
                    produto p ON tm.priproduto = p.produto
                WHERE
                    tm.itecontrol = %s
                ORDER BY
                    tm.prisequen
            """, (controle,))
            items_data = cur.fetchall()
            print(f"DEBUG: Items data for controle {controle}: {items_data}") # DEBUG

            for item in items_data:
                item_privltotal = item[6] if item[6] is not None else 0
                item_privlipi = item[8] if item[8] is not None else 0
                item_privlsubst = item[9] if item[9] is not None else 0
                
                valor_total_item = item_privltotal + item_privlipi + item_privlsubst

                invoice_items.append({
                    'prisequen': item[0],
                    'priproduto': item[1],
                    'pronome': item[2],
                    'unimedida': item[3],
                    'priquanti': item[4],
                    'pritmpuni': item[5],
                    'privltotal': item_privltotal,
                    'prialqipi': item[7],
                    'privlipi': item_privlipi,
                    'privlsubst': item_privlsubst,
                    'valor_total_item': valor_total_item
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
