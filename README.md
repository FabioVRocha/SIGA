# SIGA - Sistema Integrado de Gestão Administrativa

Sistema ERP (Enterprise Resource Planning) completo desenvolvido em Python/Flask para gestão empresarial integrada, com foco em manufatura e distribuição.

## Visão Geral

O SIGA é uma plataforma web de gestão empresarial que integra diversos módulos para controle completo de operações comerciais, produção, estoque e finanças. O sistema conecta-se a um banco de dados ERP existente em PostgreSQL e fornece uma interface moderna e intuitiva para visualização e gerenciamento de dados.

## Funcionalidades Principais

### Cadastros
- **Empresas/Clientes**: Gestão completa de cadastro de clientes
- **Produtos**: Catálogo de produtos com múltiplas linhas
- **Vendedores**: Controle de representantes de vendas
- **Cidades**: Base de dados geográfica
- **Grupos de Produtos**: Categorização de produtos
- **Condições de Pagamento**: Gestão de termos comerciais
- **Transportadoras**: Cadastro de transportadores

### Comercial
- **Espelho de Notas Fiscais**: Rastreamento detalhado de notas fiscais com filtros avançados
- **Pedidos de Venda**: Gestão completa de pedidos com rastreamento de status
- **Lotes de Carga**: Gerenciamento de lotes de envio e agrupamento de pedidos
- **Assistência Técnica**: Rastreamento de solicitações de serviço
- **Devoluções**: Gestão de devoluções de produtos

### Produção
- **Consulta de Pedidos**: Rastreamento de pedidos de produção com filtros detalhados:
  - Sequenciamento de lotes de carga
  - Rastreamento de lotes de produção
  - Status de aprovação e situação
  - Controle de separação (Reservado/Separado/Carregado)

- **Mapa Interativo**: Planejamento avançado de rotas com:
  - Visualização geográfica de lotes de carga
  - Otimização de rotas usando algoritmo 2-opt
  - Cálculo de distâncias e durações
  - Pontos personalizados de início/fim
  - Integração com OSRM para roteamento em tempo real

### Financeiro
- **Contas a Receber**: Gestão de recebíveis
- **Contas a Pagar**: Controle de pagamentos
- **Títulos**: Gerenciamento de títulos financeiros
- **Cheques Pré-datados**: Controle de cheques

### Estoque
- **Movimentações**: Rastreamento de movimentos de estoque
- **Lotes**: Gestão de lotes de produtos

### Relatórios
- Comparativo de Faturamento
- Faturamento por CFOP
- Faturamento por Linha de Produto
- Preço Médio
- Faturamento por Dia
- Faturamento por Estado
- Faturamento por Vendedor
- Vendas por Produto
- Vendas por Cliente
- Resumo Financeiro

### Gerencial
- Backup de Banco de Dados
- Gestão de Usuários
- Parâmetros do Sistema

## Tecnologias Utilizadas

### Backend
- **Python**: Linguagem principal
- **Flask 2.3.2**: Framework web
- **PostgreSQL**: Banco de dados
- **psycopg2-binary 2.9.9**: Conector PostgreSQL
- **Werkzeug 2.3.7**: Segurança e hashing de senhas

### Frontend
- **Tailwind CSS**: Framework CSS moderno
- **Font Awesome 6.0**: Biblioteca de ícones
- **JavaScript**: Interatividade client-side
- **Jinja2**: Template engine
- **Google Fonts (Inter)**: Tipografia

### APIs Externas
- **OSRM**: Otimização de rotas
- **Nominatim**: Geocodificação

## Requisitos

- Python 3.x
- PostgreSQL
- Bibliotecas Python (ver `requirements.txt`)

## Instalação

1. Clone o repositório:
```bash
git clone <url-do-repositorio>
cd siga
```

2. Crie um ambiente virtual:
```bash
python -m venv venv
```

3. Ative o ambiente virtual:

**Windows:**
```bash
venv\Scripts\activate
```

**Linux/Mac:**
```bash
source venv/bin/activate
```

4. Instale as dependências:
```bash
pip install -r requirements.txt
```

## Configuração

1. Configure o arquivo `config.py` com suas credenciais de banco de dados:

```python
# Banco de dados principal ERP
DB_CONFIG = {
    'dbname': 'seu_banco',
    'user': 'seu_usuario',
    'password': 'sua_senha',
    'host': 'seu_host',
    'port': 'sua_porta'
}

# Banco de dados auxiliar
AUXILIARY_DB_CONFIG = {
    'dbname': 'siga_db',
    'user': 'seu_usuario',
    'password': 'sua_senha',
    'host': 'seu_host',
    'port': 'sua_porta'
}

# Chave secreta do Flask
SECRET_KEY = 'sua-chave-secreta-aqui'
```

2. Crie o banco de dados auxiliar e as tabelas necessárias:

```sql
CREATE DATABASE siga_db;

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(80) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL
);

CREATE TABLE user_parameters (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    parameter_name VARCHAR(100),
    parameter_value TEXT
);
```

## Executando o Sistema

1. Inicie a aplicação:
```bash
python app.py
```

2. Acesse no navegador:
```
http://localhost:5000
```

3. Faça login com suas credenciais ou registre um novo usuário.

## Estrutura do Projeto

```
siga/
├── app.py                  # Aplicação principal Flask
├── config.py               # Configurações do sistema
├── requirements.txt        # Dependências Python
├── templates/              # Templates HTML
│   ├── base.html          # Template base
│   ├── dashboard.html     # Página inicial
│   ├── login.html         # Página de login
│   ├── orders_list.html   # Lista de pedidos
│   ├── sales_orders_list.html  # Lista de pedidos de venda
│   ├── load_lots.html     # Lotes de carga
│   ├── load_lot_map.html  # Mapa interativo
│   └── ...                # Outros templates
└── static/                 # Arquivos estáticos (se houver)
```

## Recursos Destacados

### Otimização de Rotas
- Cálculo de distâncias usando fórmula de Haversine
- Integração com OSRM para roteamento em tempo real
- Algoritmo 2-opt para otimização de rotas
- Configuração de waypoints personalizados
- Preferências de rota por usuário

### Filtros Dinâmicos
- Filtros avançados em todas as visualizações
- Busca específica por coluna
- Filtros de intervalo de data
- Dropdowns multi-seleção
- Colunas ordenáveis
- Estado de filtro preservado

### Personalização por Usuário
- Armazenamento de parâmetros por usuário
- Configurações de relatórios customizáveis
- Preferências de filtros salvos

## Segurança

### Implementado
- Hash de senhas com Werkzeug
- Autenticação baseada em sessão
- Decorador `login_required` para rotas protegidas
- Consultas SQL parametrizadas (proteção contra SQL injection)

### Considerações
⚠️ **IMPORTANTE**: Antes de colocar em produção:
- Remova credenciais hardcoded do `config.py`
- Use variáveis de ambiente para informações sensíveis
- Configure HTTPS
- Implemente rate limiting
- Configure firewall adequado para o banco de dados

## Design da Interface

O sistema utiliza uma paleta de cores moderna:
- **Azul Escuro (#1F3A5F)**: Primário/sidebar
- **Azul Claro (#4F83CC)**: Acentos/hover
- **Cinza Claro (#F4F6F8)**: Background
- **Verde Sucesso (#27AE60)**
- **Vermelho Erro (#E74C3C)**
- **Amarelo Aviso (#F1C40F)**

## Contribuindo

Contribuições são bem-vindas! Por favor:
1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

## Licença

[Definir licença apropriada]

## Suporte

Para questões e suporte, entre em contato com a equipe de desenvolvimento.

---

**Desenvolvido com Flask e PostgreSQL**
