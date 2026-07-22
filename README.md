# FCG - FIAP Cloud Games | OrchestrationAPI

Repositório de orquestração da arquitetura de microsserviços da **FIAP Cloud Games (FCG)**, desenvolvido como entregável do **Tech Challenge — PosTech FIAP** (Fase 3 e Fase 4).

Este repositório contém:
- `docker-compose.yml` — sobe toda a infraestrutura e microsserviços localmente
- `k8s/` — manifestos Kubernetes para execução em cluster (local e AKS)
- `k8s/kong/` — manifestos do Kong API Gateway
- `k8s/elasticsearch.yaml` — Elasticsearch self-hosted no cluster (Fase 4)
- `terraform/` — Infraestrutura como Código: AKS, ACR e OIDC do GitHub Actions (Fase 4)
- `observability/` — configurações de Prometheus e Grafana para Docker Compose
- `start-ecosystem.ps1` — script único que sobe todo o ecossistema do zero

---

## Fase 3 — O que foi implementado

### 1. API Gateway — Kong
Todas as requisições externas passam pelo Kong antes de chegar aos microsserviços. Plugins configurados: JWT (autenticação), rate-limiting (30 req/min), CORS e request-size-limiting.

### 2. Arquitetura Serverless — AWS Lambda (LocalStack)
O microsserviço NotificationsAPI foi migrado de um container contínuo para uma **função AWS Lambda** (`provided.al2023`). A função é acionada por mensagens do RabbitMQ via um bridge Node.js. Toda a infraestrutura está declarada em **Terraform** (`NotificationsAPI/infra/`).

### 3. Observabilidade — Opção A: Prometheus + Grafana
UsersAPI e CatalogAPI expõem métricas no formato Prometheus (`/metrics`). O Grafana disponibiliza um dashboard com: latência (P50/P95/P99), taxa de requisições, taxa de erros (5xx) e contagem por status code HTTP. Os manifestos Kubernetes estão em `k8s/`.

### 4. Persistência Poliglota
- **Redis** (cache distribuído): UsersAPI usa `IDistributedCache` com `StackExchange.Redis`. Consultas ao banco SQL Server são cacheadas por 10 minutos com a chave `UsersAPI:usuario:{guid}`.
- **MongoDB** (NoSQL com driver oficial): CatalogAPI usa `MongoDB.Driver` para persistir avaliações de jogos (`GameRating`) na collection `game_ratings` do banco `MS_CatalogAPI`. Endpoints: `POST /api/Game/{id}/ratings` e `GET /api/Game/{id}/ratings`.

---

## Fase 4 — O que foi implementado

### 1. Infraestrutura Gerenciada em Nuvem Real — Azure AKS via Terraform
Todo o cluster Kubernetes de produção é provisionado via **Terraform** (`terraform/`), não mais só local:

| Arquivo | Recurso |
|---|---|
| `terraform/aks.tf` | Cluster **Azure Kubernetes Service (AKS)**, RBAC do Azure AD habilitado |
| `terraform/acr.tf` | **Azure Container Registry (ACR)** privado, com `AcrPull` concedido à identidade do AKS |
| `terraform/github-oidc.tf` | Federação OIDC para o GitHub Actions autenticar na Azure sem senha/secret estático |
| `terraform/network.tf` | Rede virtual e subnet dedicadas ao cluster |
| `terraform/variables.tf` / `terraform.tfvars.example` | Variáveis configuráveis (nome do cluster, região, tamanho de VM) |

> 💡 **Decisão documentada:** o AKS bloqueia VMs do tier gratuito (`Standard_B2pts_v2`/`B2ats_v2`) em qualquer node pool — erros `SystemPoolSkuTooLow` e `VMSizeRestrictedByAKS` surgem mesmo fora do pool de sistema. Não há contorno: rodar AKS de verdade exige uma VM paga, mesmo que pequena. Optamos pela menor opção viável, `Standard_D2s_v3` (2 vCPU/8GB, ~US$0,10/hora). O control plane do AKS, o ACR e o Load Balancer continuam gratuitos — só a VM em si é paga.

### 2. Pipeline de CI/CD — GitHub Actions
UsersAPI e CatalogAPI têm workflows próprios (`.github/workflows/ci-cd.yml` em cada repositório) que fazem build, testes, scan de vulnerabilidades (Trivy), push para o ACR e deploy via Rolling Update no AKS — autenticados via OIDC usando a federação criada em `terraform/github-oidc.tf`.

### 3. Exposição Externa — Kong via LoadBalancer
Em produção, os serviços não usam mais NodePort: o `service.yaml` de cada microsserviço é `ClusterIP`, e todo o acesso externo passa pelo **Kong**, exposto como `LoadBalancer` no cluster AKS.

### 4. Busca Avançada — Elasticsearch self-hosted
`k8s/elasticsearch.yaml` sobe o Elasticsearch diretamente no cluster (self-hosted via manifesto, sem depender de serviço gerenciado pago). A CatalogAPI consome esse Elasticsearch para o endpoint `GET /api/Search`, com fuzzy search e ordenação por relevância. O índice é sincronizado automaticamente a cada cadastro/atualização de jogo.

---

## Arquitetura

```
                       ┌──────────────────────────────────┐
                       │       Kong API Gateway            │
                       │  JWT · Rate-Limit · CORS          │
                       │  porta 8000 (proxy)               │
                       └─────────────┬────────────────────┘
                                     │
                  ┌──────────────────┼──────────────────┐
                  ▼                                     ▼
          ┌──────────────┐                    ┌──────────────────┐
          │   UsersAPI   │                    │   CatalogAPI     │
          │  porta 5001  │                    │   porta 5002     │
          │  Redis cache │                    │  MongoDB ratings │
          └──────┬───────┘                    └────────┬─────────┘
                 │                                     │
                 └──────────────┬──────────────────────┘
                                │ RabbitMQ (5672)
                 ┌──────────────┼──────────────────────┐
                 ▼                                     ▼
         ┌──────────────┐               ┌──────────────────────────┐
         │ PaymentsAPI  │               │  NotificationsAPI        │
         │  porta 5003  │               │  AWS Lambda (LocalStack) │
         └──────────────┘               │  porta 4566              │
                                        └──────────────────────────┘
```

### Microsserviços

| Servico | Responsabilidade | Porta (Docker) |
|---|---|---|
| **UsersAPI** | Cadastro e autenticacao de usuarios (JWT) + Redis cache | `5001` |
| **CatalogAPI** | CRUD de jogos, compras, avaliações (MongoDB) | `5002` |
| **PaymentsAPI** | Processamento de pagamentos | `5003` |
| **NotificationsAPI** | Lambda AWS — triggered por RabbitMQ via LocalStack | `4566` |

### Infraestrutura

| Servico | Descricao | Porta |
|---|---|---|
| **SQL Server 2022** | Banco relacional (4 databases) | `1433` |
| **MongoDB 7** | Logs (Serilog) + avaliações de jogos (MongoDB.Driver) | `27017` |
| **Mongo Express** | Interface web para o MongoDB | `8081` |
| **RabbitMQ** | Broker de mensagens + Management UI | `5672` / `15672` |
| **Redis 7** | Cache distribuido para UsersAPI | `6379` |
| **LocalStack** | Emulação AWS local (Lambda, S3, IAM, CloudWatch) | `4566` |
| **Prometheus** | Coleta de metricas dos microsservicos | `9090` |
| **Grafana** | Dashboards de observabilidade | `3000` |

---

## Clonar os repositorios

Clone todos os repositorios na **mesma pasta pai**:

```bash
git clone https://github.com/pablosdlima/OrchestrationApi
git clone https://github.com/marciotorquato/UsersAPI
git clone https://github.com/marciotorquato/CatalogAPI
git clone https://github.com/marciotorquato/PaymentsAPI
git clone https://github.com/marciotorquato/NotificationsAPI
```

A estrutura de pastas deve ficar assim:

```
Projeto/
├── OrchestrationApi/       <- este repositorio
│   ├── docker-compose.yml
│   ├── k8s/
│   ├── observability/
│   └── start-ecosystem.ps1
├── UsersAPI/
├── CatalogAPI/
├── PaymentsAPI/
└── NotificationsAPI/
```


## Inicio Rapido — Script Automatico (Recomendado)

O script `start-ecosystem.ps1` executa todas as etapas do "passo a passo manual" de forma automatica e aguarda cada servico ficar disponivel antes de prosseguir.

**Requisitos:** Docker Desktop em execucao e PowerShell.

Navegar até o diretório do projeto OrchestrationAPI que contenha o arquivo start-ecosystem.ps1 e executar o comando:

```powershell
powershell -ExecutionPolicy Bypass -File ".\start-ecosystem.ps1"
```

> O script abre uma segunda janela do PowerShell para o trigger RabbitMQ → Lambda. **Mantenha essa janela aberta** durante os testes.



### Painel de Acesso Rapido

Referencia rapida de todas as ferramentas do ecossistema apos subir o ambiente.

| Ferramenta | Endereco | Usuario | Senha | Observacao |
|---|---|---|---|---|
| **UsersAPI** (Swagger) | http://localhost:5001/swagger | — | — | Cadastro, login, usuarios |
| **CatalogAPI** (Swagger) | http://localhost:5002/swagger | — | — | Jogos, compras, avaliacoes |
| **PaymentsAPI** (Swagger) | http://localhost:5003/swagger | — | — | Pagamentos |
| **RabbitMQ** (Management) | http://localhost:15672 | `RABBITMQ_DEFAULT_USER` | `RABBITMQ_DEFAULT_PASS` | Ver variaveis no `.env` local — nunca commitar valor real |
| **MongoDB** (Mongo Express) | http://localhost:8081 | `ME_CONFIG_BASICAUTH_USERNAME` | `ME_CONFIG_BASICAUTH_PASSWORD` | Ver variaveis no `.env` local — nunca commitar valor real |
| **Grafana** (Dashboards) | http://localhost:3000 | `GF_SECURITY_ADMIN_USER` | `GF_SECURITY_ADMIN_PASSWORD` | Ver variaveis no `.env` local — nunca commitar valor real |
| **Prometheus** | http://localhost:9090 | — | — | Coleta de metricas |
| **Prometheus** | http://localhost:9090/targets | — | — | Métricas criadas |
| **LocalStack** (Health) | http://localhost:4566/_localstack/health | — | — | Status dos servicos AWS emulados |
| **Redis** | `redis:6379` (interno) | — | — | Sem interface web — use `docker exec redis redis-cli` |
| **Kong** (Proxy) | http://localhost:8000 | — | — | Entrada unica para UsersAPI e CatalogAPI |
| **Kong** (Admin API) | http://localhost:8001 | — | — | Consultar rotas e plugins ativos |
| **Kong** (Manager UI) | http://localhost:8002 | — | — | Interface web de gerenciamento |

---

## Passo a Passo Manual

Siga estas etapas se preferir executar cada comando individualmente ou precisar diagnosticar um problema.

### Pre-requisitos

Antes de iniciar, certifique-se de ter instalado:

| Ferramenta | Versao minima | Como verificar |
|---|---|---|
| Docker Desktop | 4.x | `docker --version` |
| PowerShell | 5.1 | `$PSVersionTable.PSVersion` |
| Node.js (opcional) | 18+ | `node --version` |
| Terraform (opcional) | 1.6+ | `terraform --version` |

---

### Etapa 0 — Limpar o ambiente anterior

> **Aviso:** os comandos abaixo removem TODOS os containers, imagens, volumes e dados Docker da maquina. Execute apenas se quiser partir do zero.

```powershell
# Remove todos os containers, imagens, volumes e redes nao utilizadas
docker system prune -a --volumes -f

# Remove todos os recursos do cluster Kubernetes ativo (se aplicavel)
kubectl delete all --all
```

---



### Etapa 2 — Subir infraestrutura e microsservicos

Abra um terminal PowerShell na raiz do projeto (pasta pai dos repositorios) e execute:

```powershell
cd OrchestrationApi
docker compose up --build -d
```

Este comando sobe:
- SQL Server, MongoDB, Redis, RabbitMQ
- LocalStack (emulacao AWS)
- Prometheus e Grafana
- UsersAPI, CatalogAPI, PaymentsAPI

> Na **primeira execucao** o Docker ira baixar todas as imagens e compilar os projetos .NET. Isso pode levar **5 a 10 minutos**.

---

### Etapa 3 — Aguardar os servicos ficarem prontos

Acompanhe os logs para confirmar que todos os servicos subiram:

```powershell
# Ver logs em tempo real de todos os servicos
docker compose logs -f

# Ou verificar apenas o status dos containers
docker compose ps
```

Aguarde ate ver as seguintes mensagens nos logs:

```
users-api    | Application started.
catalog-api  | Application started.
payments-api | Application started.
```

**Verificar o RabbitMQ** (deve retornar JSON com informacoes do servidor):
```powershell
Invoke-RestMethod -Uri "http://localhost:15672/api/overview" `
    -Headers @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$env:RABBITMQ_DEFAULT_USER`:$env:RABBITMQ_DEFAULT_PASS")) }
```

**Verificar o LocalStack** (campo `lambda` deve ser `"running"` ou `"available"`):
```powershell
Invoke-RestMethod -Uri "http://localhost:4566/_localstack/health"
```

---

### Etapa 4 — Deploy da Lambda NotificationsAPI

Com o LocalStack e RabbitMQ funcionando, faca o deploy da funcao Lambda:

```powershell
cd ..\NotificationsAPI
powershell -ExecutionPolicy Bypass -File ".\scripts\build-deploy-localstack.ps1"
```

Este script:
1. Compila o projeto `NotificationsAPI.Function` dentro de um container Docker (runtime linux-x64)
2. Cria o pacote `.zip` em `artifacts/lambda/`
3. Detecta e usa automaticamente: `tflocal` → `terraform` → `awslocal` (nessa ordem)
4. Cria no LocalStack: IAM role, S3 bucket, objeto S3 e funcao Lambda
5. Configura filas e exchanges no RabbitMQ

> Se o Terraform nao estiver instalado, o script usa `awslocal` automaticamente. O deploy funciona nos dois casos.

**Verificar se a Lambda foi criada:**
```powershell
docker exec localstack awslocal lambda list-functions --query "Functions[*].FunctionName"
```

Deve retornar: `"notifications-api-function"`

---

### Etapa 5 — Iniciar o trigger RabbitMQ → Lambda

A Lambda precisa de um bridge que consome as mensagens do RabbitMQ e invoca a funcao. Execute em um **terminal separado** (mantenha-o aberto):

```powershell
cd ..\NotificationsAPI
powershell -ExecutionPolicy Bypass -File ".\scripts\start-rabbitmq-lambda-trigger.ps1"
```

Voce deve ver mensagens como:
```
[trigger] Conectado ao RabbitMQ.
[trigger] Aguardando mensagens nas filas...
```

> **Importante:** enquanto este terminal estiver aberto, toda mensagem publicada no RabbitMQ sera entregue para a Lambda.

---

### Etapa 6 — Testar o ecossistema (opcional)

Envie mensagens de teste para validar o fluxo completo:

```powershell
cd ..\NotificationsAPI
powershell -ExecutionPolicy Bypass -File ".\scripts\send-test-messages.ps1"
```

Verifique os logs da Lambda no LocalStack:
```powershell
# Listar log streams
docker exec localstack awslocal logs describe-log-streams `
    --log-group-name "/aws/lambda/notifications-api-function"

# Ver logs do stream mais recente
docker exec localstack awslocal logs get-log-events `
    --log-group-name "/aws/lambda/notifications-api-function" `
    --log-stream-name "NOME_DO_STREAM_AQUI"
```

---

## Acessando os Servicos

Apos subir todo o ecossistema, use as URLs abaixo para acessar cada servico:

### Microsservicos (Swagger)

| Servico | URL | Descricao |
|---|---|---|
| **UsersAPI** | http://localhost:5001/swagger | Cadastro, login e gerenciamento de usuarios |
| **CatalogAPI** | http://localhost:5002/swagger | Jogos, compras e avaliacoes (MongoDB) |
| **PaymentsAPI** | http://localhost:5003/swagger | Processamento de pagamentos |

### Mensageria

| Servico | URL | Credenciais |
|---|---|---|
| **RabbitMQ Management** | http://localhost:15672 | ver `RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` no `.env` local |

No RabbitMQ Management voce pode:
- Ver filas em `Queues` — procure `user-created-queue-notifications` e `payment-processed-queue-notifications`
- Ver exchanges em `Exchanges` — procure `user-created-exchange` e `payment-processed-exchange`
- Monitorar mensagens em transito em `Overview`

### Banco de Dados

| Servico | URL | Credenciais |
|---|---|---|
| **Mongo Express** | http://localhost:8081 | ver `ME_CONFIG_BASICAUTH_USERNAME` / `ME_CONFIG_BASICAUTH_PASSWORD` no `.env` local |

No Mongo Express voce pode:
- Ver os logs de todos os servicos no banco `logs_dev`
- Ver as avaliacoes de jogos no banco `MS_CatalogAPI`, collection `game_ratings`

**Redis** nao possui interface web por padrao. Para inspecionar as chaves via CLI:
```powershell
# Listar todas as chaves de cache da UsersAPI
docker exec redis redis-cli KEYS "UsersAPI:*"

# Ver o valor de uma chave especifica
docker exec redis redis-cli GET "UsersAPI:usuario:SEU-GUID-AQUI"

# Ver o TTL restante de uma chave
docker exec redis redis-cli TTL "UsersAPI:usuario:SEU-GUID-AQUI"
```

### Observabilidade

| Servico | URL | Credenciais |
|---|---|---|
| **Grafana** | http://localhost:3000 | ver `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` no `.env` local |
| **Prometheus** | http://localhost:9090 | sem autenticacao |

No **Grafana**:
1. Acesse http://localhost:3000 e faca login
2. Va em `Dashboards` no menu lateral
3. Abra o dashboard **"FCG - FIAP Cloud Games"**
4. O dashboard exibe: latencia P50/P95/P99, requisicoes por segundo, taxa de erros 5xx e contagem por status code HTTP

No **Prometheus**:
- Acesse http://localhost:9090 e use a aba `Graph` para executar queries
- Exemplos de queries uteis:
  ```
  rate(http_requests_received_total[1m])
  histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
  ```
- Verifique os targets em `Status > Targets` — `users-api` e `catalog-api` devem estar `UP`

### Serverless (LocalStack)

| Servico | URL | Descricao |
|---|---|---|
| **LocalStack Health** | http://localhost:4566/_localstack/health | Status dos servicos AWS emulados |
| **LocalStack API** | http://localhost:4566 | Endpoint unico para todos os servicos AWS |

```powershell
# Verificar funcoes Lambda existentes
docker exec localstack awslocal lambda list-functions

# Verificar buckets S3
docker exec localstack awslocal s3 ls

# Verificar IAM roles
docker exec localstack awslocal iam list-roles
```

### API Gateway (Kong)

| Interface | URL | Descricao |
|---|---|---|
| **Proxy (entrada das requisicoes)** | http://localhost:8000 | Use esta URL para chamar os microsservicos |
| **Admin API** | http://localhost:8001 | Consultar configuracoes do Kong |
| **Kong Manager** | http://localhost:8002 | Interface web de gerenciamento |

> O Kong sobe automaticamente com o `docker compose up`. A configuracao declarativa esta em `kong/kong.yaml`. No Kubernetes, use os manifestos em `k8s/kong/`.

---

## API Gateway — Kong

O Kong e o **ponto de entrada unico** da plataforma. Todas as requisicoes externas passam pelo Kong antes de chegar nos microsservicos.

### Fluxo de Autenticacao

```
Cliente (Postman / App)
    │
    ▼
Kong Gateway (porta 8000)
    │
    ├── 1. Valida token JWT
    │     ├── Sem token ou invalido → 401 Unauthorized
    │     └── Token valido → continua
    │
    ├── 2. Verifica rate-limiting
    │     ├── Limite excedido → 429 Too Many Requests
    │     └── Dentro do limite → continua
    │
    ├── 3. Verifica CORS e tamanho do payload
    │     └── Payload > 10MB → 413 Payload Too Large
    │
    └── 4. Roteia para o microsservico correto
          ├── /users/*   → UsersAPI  (porta 5001 interna)
          └── /catalog/* → CatalogAPI (porta 5002 interna)
```

### Plugins de Seguranca

| Plugin | Protecao | Resposta HTTP |
|---|---|---|
| `jwt` | Token invalido ou ausente | `401 Unauthorized` |
| `rate-limiting` | Mais de 30 req/min ou 500/hora | `429 Too Many Requests` |
| `cors` | Controle de origens | bloqueio no navegador |
| `request-size-limiting` | Payload acima de 10MB | `413 Payload Too Large` |

### Subir o Kong (Kubernetes)

```powershell
# Criar o namespace
kubectl create namespace fcg-fase3

# Aplicar todos os manifestos de infraestrutura
kubectl apply -f k8s/ -n fcg-fase3

# Aplicar o Kong
kubectl apply -f k8s/kong/

# Aguardar o Kong ficar Running
kubectl get pods -n kong -w

# Acessar via port-forward
kubectl port-forward service/kong-proxy 8000:80 -n kong
```

### Testar o Kong

```powershell
# Sem token — deve retornar 401
curl http://localhost:8000/users/api/Usuarios/BuscarPorId/SEU-ID

# Com token valido
curl http://localhost:8000/users/api/Usuarios/BuscarPorId/SEU-ID `
  -H "Authorization: Bearer SEU_TOKEN"
```

> Gere o token via `POST http://localhost:5001/api/Authentication/login`

---

## Observabilidade — Opcao A: Prometheus + Grafana

**Stack escolhida:** Prometheus + Grafana (codigo aberto).

### Como funciona

1. **UsersAPI** e **CatalogAPI** expõem o endpoint `/metrics` usando `prometheus-net.AspNetCore`
2. **Prometheus** coleta (scrape) essas metricas a cada 15 segundos
3. **Grafana** consulta o Prometheus e exibe os dados em tempo real

### Metricas disponiveis no dashboard

| Painel | Metrica Prometheus |
|---|---|
| Taxa de requisicoes (req/s) | `rate(http_requests_received_total[1m])` |
| Erros 5xx | `rate(http_requests_received_total{code=~"5.."}[1m])` |
| Latencia P50 | `histogram_quantile(0.50, ...)` |
| Latencia P95 | `histogram_quantile(0.95, ...)` |
| Latencia P99 | `histogram_quantile(0.99, ...)` |
| Requisicoes por status code | `http_requests_received_total` agrupado por `code` |

### Acessar o Grafana

1. Abra http://localhost:3000
2. Login: credenciais definidas em `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` (`.env` local)
3. Menu lateral → `Dashboards` → `FCG - FIAP Cloud Games`

### Verificar targets no Prometheus

Acesse http://localhost:9090/targets e confirme que `users-api` e `catalog-api` estao com status `UP`.

### Manifestos Kubernetes (Opcao A)

Os manifestos para implantacao em cluster estao em `k8s/`:
- `k8s/prometheus-configmap.yaml` — configuracao do scrape
- `k8s/prometheus-deployment.yaml` — Deployment + Service do Prometheus
- `k8s/grafana-datasource-configmap.yaml` — datasource apontando para o Prometheus
- `k8s/grafana-dashboard-provider-configmap.yaml` — provider do dashboard
- `k8s/grafana-dashboard-configmap.yaml` — JSON do dashboard

---

## Persistencia Poliglota

### Redis — Cache Distribuido (UsersAPI)

**Biblioteca:** `Microsoft.Extensions.Caching.StackExchangeRedis` (abstração `IDistributedCache`)

**Cenario de uso:** ao buscar um usuario por ID (`GET /api/Usuarios/BuscarPorId/{id}`), o resultado e cacheado por **10 minutos**. Nas proximas chamadas com o mesmo ID, a resposta vem do Redis sem consultar o SQL Server.

**Formato da chave:** `UsersAPI:usuario:{guid-do-usuario}`

```powershell
# Inspecionar o cache no Redis
docker exec redis redis-cli KEYS "UsersAPI:*"
docker exec redis redis-cli GET "UsersAPI:usuario:SEU-GUID"
docker exec redis redis-cli TTL "UsersAPI:usuario:SEU-GUID"
```

**O cache e invalidado automaticamente quando:**
- Um usuario e atualizado (`PUT AlterarUsuario`)
- O TTL de 10 minutos expira

### MongoDB — Avaliacoes de Jogos (CatalogAPI)

**Driver oficial:** `MongoDB.Driver` v3.4.0

**Cenario de uso:** usuarios podem avaliar jogos com nota de 1 a 5 e comentario opcional. As avaliacoes sao armazenadas na collection `game_ratings` do banco `MS_CatalogAPI` no MongoDB.

**Endpoints disponiveis:**

| Metodo | Endpoint | Descricao |
|---|---|---|
| `POST` | `/api/Game/{gameId}/ratings` | Registra uma avaliacao (nota 1-5, comentario) |
| `GET` | `/api/Game/{gameId}/ratings` | Retorna sumario com media, total e lista de avaliacoes |

**Acessar as avaliacoes no Mongo Express:**
1. Abra http://localhost:8081 (credenciais definidas em `ME_CONFIG_BASICAUTH_USERNAME` / `ME_CONFIG_BASICAUTH_PASSWORD` no `.env` local)
2. Va em `MS_CatalogAPI` → `game_ratings`

---

## Serverless — NotificationsAPI Lambda

### Arquitetura

```
RabbitMQ
  ├── user-created-queue-notifications
  └── payment-processed-queue-notifications
        │
        ▼
  [bridge Node.js] — scripts/rabbitmq-lambda-trigger.js
        │
        ▼
  AWS Lambda (LocalStack)
  notifications-api-function
        │
        ▼
  SQL Server — MS_NotificationsAPI
```

### Infraestrutura como Codigo (Terraform)

O diretorio `NotificationsAPI/infra/` contem a declaracao completa dos recursos AWS:

| Arquivo | Recurso |
|---|---|
| `main.tf` | Provider AWS com suporte a LocalStack e producao |
| `variables.tf` | Variaveis configuráveis (regiao, nomes, conexoes) |
| `iam.tf` | IAM Role com `AWSLambdaBasicExecutionRole` + `AWSLambdaMQExecutionRole` |
| `s3.tf` | Bucket S3 para artefato `.zip` da Lambda |
| `lambda.tf` | Funcao Lambda + CloudWatch Log Group (retencao 7 dias) |
| `outputs.tf` | ARNs e nomes dos recursos criados |

### Como fazer redeploy da Lambda

```powershell
cd NotificationsAPI
powershell -ExecutionPolicy Bypass -File ".\scripts\build-deploy-localstack.ps1"
```

### Verificar logs da Lambda

```powershell
# Listar grupos de log
docker exec localstack awslocal logs describe-log-groups

# Listar streams do grupo
docker exec localstack awslocal logs describe-log-streams `
    --log-group-name "/aws/lambda/notifications-api-function"

# Ler logs do stream
docker exec localstack awslocal logs get-log-events `
    --log-group-name "/aws/lambda/notifications-api-function" `
    --log-stream-name "NOME_DO_STREAM"
```

---

## Fluxo de Autenticacao

**1. Cadastre um usuario (sem autenticacao):**
```bash
POST http://localhost:5001/api/Usuarios/Cadastrar
Content-Type: application/json

{
  "nome": "Seu Nome",
  "email": "email@exemplo.com",
  "senha": "SuaSenha@123",
  "role": "usuario"
}
```

**2. Faca login e copie o token:**
```bash
POST http://localhost:5001/api/Authentication/login
Content-Type: application/json

{
  "email": "email@exemplo.com",
  "senha": "SuaSenha@123"
}
```

**3. Use o token em todas as requisicoes:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## Bancos de Dados

| Servico | Banco SQL Server | Banco MongoDB |
|---|---|---|
| UsersAPI | `MS_UsersAPI` | — |
| CatalogAPI | `MS_CatalogAPI` | `MS_CatalogAPI` (collection `game_ratings`) |
| PaymentsAPI | `MS_PaymentAPI` | — |
| NotificationsAPI | `MS_NotificationsAPI` | — |
| Todos os servicos | — | `logs_dev` (Serilog) |

---

## Repositorios dos Microsservicos

| Servico | Repositorio |
|---|---|
| OrchestrationApi | https://github.com/pablosdlima/OrchestrationApi |
| UsersAPI | https://github.com/marciotorquato/UsersAPI |
| CatalogAPI | https://github.com/marciotorquato/CatalogAPI |
| PaymentsAPI | https://github.com/marciotorquato/PaymentsAPI |
| NotificationsAPI | https://github.com/marciotorquato/NotificationsAPI |

---

## Contexto Academico

Projeto desenvolvido para o **Tech Challenge** da pos-graduacao **PosTech - Arquitetura de Software em .NET com Azure** da FIAP.

**Fase 3 — Objetivo:** Profissionalizar a arquitetura de microsservicos aplicando:
- API Gateway (Kong) com JWT, rate-limiting e CORS
- Arquitetura Serverless (AWS Lambda via LocalStack) com IaC em Terraform
- Observabilidade — Opcao A: Prometheus + Grafana
- Persistencia Poliglota: Redis (cache) + MongoDB (driver oficial, dados de negocio)

**Fase 4 — Objetivo:** Levar a infraestrutura para producao real na nuvem, com automacao:
- Kubernetes gerenciado real (Azure AKS) e registro de imagens (Azure ACR), provisionados via Terraform
- Pipeline de CI/CD (GitHub Actions) com build, testes, scan de vulnerabilidades e deploy automatizado via OIDC
- Exposicao externa via Kong como `LoadBalancer` no cluster (substitui o NodePort local)
- Busca avancada com Elasticsearch self-hosted no cluster, integrada a CatalogAPI
