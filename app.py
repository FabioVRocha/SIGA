# siga_erp/app.py

from flask import Flask, render_template, redirect, url_for, g, session
from config import Config
from routes.relatorios import relatorios_bp
from routes.configuracoes import configuracoes_bp # Importa o Blueprint de configurações
from database import DBManager # Importa a classe DBManager
from datetime import datetime

# Inicializa o aplicativo Flask
app = Flask(__name__)

# Carrega as configurações da classe Config
app.config.from_object(Config)

# Inicializa os DBManagers para ambos os bancos de dados
# Eles serão acessados via current_app.db_erp e current_app.db_siga
app.db_erp = DBManager(app.config['ERP_DATABASE_URI'])
app.db_siga = DBManager(app.config['SIGA_DATABASE_URI'])


# Registra os Blueprints
app.register_blueprint(relatorios_bp, url_prefix='/relatorios')
app.register_blueprint(configuracoes_bp, url_prefix='/configuracoes') # Registra o Blueprint de configurações

@app.route('/')
def index():
    """
    Rota principal do aplicativo.
    Renderiza a página inicial com o menu de relatórios.
    Passa o objeto datetime para o template.
    """
    return render_template('index.html', datetime=datetime)

# Exemplo de rota de redirecionamento para o primeiro relatório
@app.route('/iniciar_relatorios')
def iniciar_relatorios():
    """
    Redireciona para a página do primeiro relatório.
    """
    return redirect(url_for('relatorios.espelho_notas'))


@app.route('/logout')
def logout():
    """Simples rota de logout."""
    session.clear()
    return redirect(url_for('index'))

if __name__ == '__main__':
    # Executa o aplicativo Flask
    # Em produção, use um servidor WSGI como Gunicorn ou uWSGI
    app.run(debug=True)