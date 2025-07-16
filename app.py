# siga_erp/app.py

from flask import Flask, render_template, redirect, url_for
from config import Config
from routes.relatorios import relatorios_bp # Importa o Blueprint de relatórios
from datetime import datetime # Importa o módulo datetime

# Inicializa o aplicativo Flask
app = Flask(__name__)

# Carrega as configurações da classe Config
app.config.from_object(Config)

# Registra os Blueprints
app.register_blueprint(relatorios_bp, url_prefix='/relatorios')

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

if __name__ == '__main__':
    # Executa o aplicativo Flask
    # Em produção, use um servidor WSGI como Gunicorn ou uWSGI
    app.run(debug=True)

