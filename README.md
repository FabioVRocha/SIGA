# SIGA WhatsApp Orchestrator

## Visão geral
O módulo `whatsapp_orchestrator` provê um orquestrador de conversas para WhatsApp baseado em FastAPI, com console web, APIs REST e integração com Celery, Redis, PostgreSQL, APScheduler e provedores de IA compatíveis com a API do OpenAI.【F:whatsapp_orchestrator/main.py†L26-L461】【F:whatsapp_orchestrator/tasks.py†L17-L30】【F:whatsapp_orchestrator/scheduler.py†L21-L49】【F:whatsapp_orchestrator/settings.py†L29-L95】【F:whatsapp_orchestrator/ai_client.py†L13-L94】【F:whatsapp_orchestrator/whatsapp_client.py†L15-L70】

## Arquitetura em alto nível
- **FastAPI** expõe webhooks, APIs de gestão de fluxos e o console HTML por meio de templates Jinja2.【F:whatsapp_orchestrator/main.py†L26-L360】  
- **Celery + Redis** executa nós de forma assíncrona e processa agendamentos por meio da task `whatsapp.execute_node`. Configure o broker/result backend nas variáveis `WORKFLOW_CELERY_BROKER_URL` e `WORKFLOW_CELERY_RESULT_BACKEND`.【F:whatsapp_orchestrator/tasks.py†L17-L30】【F:whatsapp_orchestrator/settings.py†L38-L45】  
- **APScheduler** verifica periodicamente ações atrasadas e reencaminha execuções para o Celery, garantindo que `delay_seconds` seja respeitado mesmo após reinícios.【F:whatsapp_orchestrator/scheduler.py†L21-L49】【F:whatsapp_orchestrator/workflow_engine.py†L418-L435】  
- **PostgreSQL** armazena fluxos, nós, execuções, logs, contatos e ações agendadas utilizando SQLAlchemy ORM.【F:whatsapp_orchestrator/models.py†L44-L181】【F:whatsapp_orchestrator/database.py†L12-L38】  
- **WhatsApp Business Platform** é chamada via `WhatsAppClient`, que também suporta execução simulada quando credenciais não estão presentes.【F:whatsapp_orchestrator/whatsapp_client.py†L15-L70】  
- **IA generativa** opcional utiliza `AIChatClient` para gerar respostas em nós `ai_completion`, com suporte a prompts dinâmicos, histórico e envio automático da resposta ao contato.【F:whatsapp_orchestrator/workflow_engine.py†L233-L425】【F:whatsapp_orchestrator/ai_client.py†L13-L94】

## Pré-requisitos
- Python 3.11+
- PostgreSQL acessível com um banco dedicado ao orquestrador.
- Redis (ou outro broker suportado pelo Celery) para filas assíncronas.
- Credenciais da WhatsApp Business Platform (ou equivalente) para envio real de mensagens.
- Opcional: chave de API e modelo compatível com OpenAI para habilitar nós de IA.

## Instalação
1. Crie um ambiente virtual e instale as dependências:
   ```bash
   python -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```
2. Configure o acesso ao PostgreSQL e às integrações por variáveis de ambiente. Todas as configurações usam o prefixo `WORKFLOW_` e possuem padrões definidos em `Settings`.【F:whatsapp_orchestrator/settings.py†L26-L95】  
   Exemplo de `.env`:
   ```env
   WORKFLOW_DB_HOST=localhost
   WORKFLOW_DB_PORT=5432
   WORKFLOW_DB_USER=postgres
   WORKFLOW_DB_PASSWORD=postgres
   WORKFLOW_DB_NAME=siga_workflows
   WORKFLOW_CELERY_BROKER_URL=redis://localhost:6379/0
   WORKFLOW_CELERY_RESULT_BACKEND=redis://localhost:6379/1
   WORKFLOW_WHATSAPP_API_BASE_URL=https://graph.facebook.com/v18.0
   WORKFLOW_WHATSAPP_PHONE_NUMBER_ID=YOUR_PHONE_NUMBER_ID
   WORKFLOW_WHATSAPP_ACCESS_TOKEN=YOUR_TOKEN
   WORKFLOW_WEBHOOK_VERIFY_TOKEN=YOUR_VERIFY_TOKEN
   WORKFLOW_DEFAULT_FLOW_ID=1
   WORKFLOW_OPENAI_API_BASE=https://api.openai.com/v1
   WORKFLOW_OPENAI_API_KEY=sk-...
   WORKFLOW_OPENAI_DEFAULT_MODEL=gpt-3.5-turbo
   WORKFLOW_AI_DEFAULT_SYSTEM_PROMPT=Você é um assistente virtual do SIGA.
   ```
3. Ajuste o módulo `config.py` se desejar compartilhar credenciais padrão com outras partes do SIGA; os valores são importados automaticamente quando disponíveis.【F:whatsapp_orchestrator/settings.py†L8-L23】

## Banco de dados
A aplicação cria automaticamente as tabelas necessárias ao iniciar (`Base.metadata.create_all`).【F:whatsapp_orchestrator/main.py†L65-L71】  
O schema inclui fluxos, nós, transições, contatos, execuções, logs e ações agendadas para rastrear todo o histórico de conversas.【F:whatsapp_orchestrator/models.py†L44-L181】

## Executando os serviços
1. Inicie o backend FastAPI (o APScheduler é inicializado junto na partida da aplicação):
   ```bash
   uvicorn whatsapp_orchestrator.main:app --reload
   ```
   O processo de inicialização registra o agendador e deixa o console web disponível em `http://localhost:8000/`.【F:whatsapp_orchestrator/main.py†L65-L108】
2. Em um terminal separado, suba o worker Celery:
   ```bash
   celery -A whatsapp_orchestrator.tasks.celery_app worker --loglevel=info
   ```
   Essa task executa nós pendentes utilizando sessões próprias de banco.【F:whatsapp_orchestrator/tasks.py†L17-L30】
3. Garanta que Redis (ou o broker configurado) esteja ativo e acessível pelo worker e pela API.

## Webhook do WhatsApp
Configure o endpoint de verificação (`GET /webhook/whatsapp`) no painel do Meta usando o `WORKFLOW_WEBHOOK_VERIFY_TOKEN`. Requisições válidas retornam o `hub.challenge` recebido.【F:whatsapp_orchestrator/main.py†L363-L370】  
As mensagens recebidas devem ser postadas em `POST /webhook/whatsapp`, que processa contatos, execuções e encaminha nós para o Celery quando necessário.【F:whatsapp_orchestrator/main.py†L372-L380】【F:whatsapp_orchestrator/workflow_engine.py†L41-L172】

## Console web e APIs
- Console HTML: `GET /` lista fluxos, `GET/POST /console/flows/...` permitem criar, editar e excluir fluxos e nós via formulários.【F:whatsapp_orchestrator/main.py†L86-L360】  
- APIs REST: `GET/POST/PATCH /flows`, `POST /flows/{flow_id}/nodes`, `PATCH /flows/{flow_id}/nodes/{node_id}`, `DELETE /flows/{flow_id}/nodes/{node_id}` para gestão programática dos fluxos.【F:whatsapp_orchestrator/main.py†L383-L445】  
- Execução manual: `POST /flows/start` cria uma execução para um contato e dispara o primeiro nó imediatamente se existir.【F:whatsapp_orchestrator/main.py†L448-L461】【F:whatsapp_orchestrator/schemas.py†L131-L135】

## Modelagem de fluxos
Os fluxos são compostos por nós (`FlowNode`) e transições (`FlowTransition`) ligadas ao estado (`context`) de cada execução.【F:whatsapp_orchestrator/models.py†L66-L110】【F:whatsapp_orchestrator/crud.py†L30-L198】  
Cada nó possui um `node_type` e um dicionário `config` que controlam seu comportamento.【F:whatsapp_orchestrator/models.py†L66-L88】【F:whatsapp_orchestrator/workflow_engine.py†L152-L425】  
Expressões condicionais para transições são avaliadas com segurança usando uma AST restrita, permitindo operadores lógicos básicos sobre valores do contexto.【F:whatsapp_orchestrator/crud.py†L180-L300】

### Tipos de nó suportados
- **send_message**: envia mensagens de texto ao contato. Utilize `message` (suporta `str.format` com o contexto), `preview_url` e `delay_seconds` para agendamentos encadeados.【F:whatsapp_orchestrator/workflow_engine.py†L174-L206】
- **wait_for_input**: pausa a execução até receber a próxima mensagem; define `context_key` para persistir a resposta do usuário.【F:whatsapp_orchestrator/workflow_engine.py†L208-L225】
- **decision**: avalia as transições configuradas e segue o primeiro caminho cuja condição retorne verdadeiro; se nenhum corresponder, encerra a execução.【F:whatsapp_orchestrator/workflow_engine.py†L227-L231】【F:whatsapp_orchestrator/crud.py†L180-L198】
- **ai_completion**: gera respostas usando IA. Opções de configuração incluem:
  - `prompt_template` ou `prompt` (Jinja2) e `system_prompt` para construir mensagens.
  - `context_key` / `response_alias` para armazenar resultados no contexto.
  - `history_context_key`, `append_history`, `store_raw_message` e `store_full_response` para manter histórico estruturado.
  - `model`, `temperature`, `max_tokens`, `extra_body` para ajustar a chamada ao provedor.
  - `send_response`, `response_template`, `preview_url` e `delay_seconds` para responder ao contato e encadear próximos nós.【F:whatsapp_orchestrator/workflow_engine.py†L233-L425】【F:whatsapp_orchestrator/settings.py†L65-L85】
- **end**: finaliza a execução marcando o status como `completed`.【F:whatsapp_orchestrator/workflow_engine.py†L167-L171】

### Histórico e contexto
O estado da conversa é persistido por execução, incluindo campos calculados (`last_message`, prompts, respostas de IA) e logs detalhados de cada evento.【F:whatsapp_orchestrator/workflow_engine.py†L95-L386】【F:whatsapp_orchestrator/crud.py†L153-L177】【F:whatsapp_orchestrator/models.py†L127-L166】

## Integração com IA
Defina `WORKFLOW_OPENAI_API_KEY`, `WORKFLOW_OPENAI_API_BASE` e `WORKFLOW_OPENAI_DEFAULT_MODEL` para habilitar os nós `ai_completion`. O cliente valida a presença da chave antes de realizar chamadas e registra erros ou execuções simuladas se estiver ausente.【F:whatsapp_orchestrator/ai_client.py†L17-L94】【F:whatsapp_orchestrator/workflow_engine.py†L304-L345】

## Boas práticas e segurança
- Utilize o `WORKFLOW_WEBHOOK_VERIFY_TOKEN` para proteger o webhook público.【F:whatsapp_orchestrator/main.py†L363-L370】
- Configure variáveis sensíveis por meio do `.env` ou secret manager; tokens de WhatsApp e IA nunca são logados em texto puro.【F:whatsapp_orchestrator/settings.py†L58-L85】【F:whatsapp_orchestrator/whatsapp_client.py†L21-L70】
- Revise e limpe periodicamente o contexto armazenado para cumprir políticas de privacidade e LGPD.

## Testes rápidos
Execute uma verificação de sintaxe antes do deploy:
```bash
python -m compileall whatsapp_orchestrator
```