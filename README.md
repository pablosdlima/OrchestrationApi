# 🎮 FCG - FIAP Cloud Games | OrchestrationAPI

Repositório de orquestração da arquitetura de microsserviços da **FIAP Cloud Games (FCG)**, desenvolvido como entregável do **Tech Challenge Fase 3 - PosTech FIAP**.

Este repositório contém:
- `docker-compose.yml` — sobe toda a infraestrutura e microsserviços em ambiente local
- `k8s/` — manifestos Kubernetes para execução em cluster
- `k8s/kong/` — manifestos do Kong API Gateway
- `kong-visual/` — ambiente de demonstração visual com Konga

---

## 📐 Arquitetura

A plataforma FCG opera com uma arquitetura de **microsserviços orientada a eventos**, utilizando RabbitMQ como broker de mensagens. Na Fase 3, foi adicionado um **API Gateway** como ponto de entrada único, centralizando autenticação e roteamento.

```
                        ┌─────────────────────────────┐
                        │      Kong API Gateway        │
                        │  JWT · Rate Limit · CORS     │
                        └──────────────┬──────────────┘
                                       │
                   ┌───────────────────┼───────────────────┐
                   ▼                                       ▼
           ┌──────────────┐                      ┌──────────────┐
           │   UsersAPI   │                      │  CatalogAPI  │
           └──────────────┘                      └──────────────┘
                   │                                       │
                   └───────────────────┬───────────────────┘
                                       │ RabbitMQ
                   ┌───────────────────┼───────────────────┐
                   ▼                                       ▼
           ┌──────────────┐                      ┌──────────────────┐
           │ PaymentsAPI  │                      │ NotificationsAPI │
           └──────────────┘                      └──────────────────┘
```

### Microsserviços

| Serviço | Responsabilidade | Porta (Docker) | Porta (Kubernetes) |
|---|---|---|---|
| **UsersAPI** | Cadastro e autenticação de usuários (JWT) | `5001` | `30001` |
| **CatalogAPI** | CRUD de jogos e início do fluxo de compra | `5002` | `30002` |
| **PaymentsAPI** | Processamento de pagamentos | `5003` | `30003` |
| **NotificationsAPI** | Envio de notificações por e-mail (log no console) | `5004` | `30004` |

### Infraestrutura

| Serviço | Descrição | Porta |
|---|---|---|
| **SQL Server 2022** | Banco de dados relacional (1 instância, 4 databases) | `1433` |
| **MongoDB 7** | Armazenamento de logs (Serilog) | `27017` |
| **Mongo Express** | Interface web para o MongoDB | `8081` |
| **RabbitMQ** | Broker de mensagens + Management UI | `5672` / `15672` |

### Fluxo de Eventos (RabbitMQ)

```
UsersAPI
  └── publica → user-created-exchange
        └── NotificationsAPI consome → envia e-mail de boas-vindas

CatalogAPI
  └── publica → order-placed-exchange
        └── PaymentsAPI consome → processa pagamento
              └── publica → payment-processed-exchange
                    ├── CatalogAPI consome → libera jogo na biblioteca
                    └── NotificationsAPI consome → notifica resultado do pagamento
```

---

## 🔀 Kong API Gateway

O Kong é o **ponto de entrada único** da plataforma. Todas as requisições externas passam pelo Kong antes de chegar nos microsserviços.

### Fluxo de Autenticação

```
Cliente (Postman/App)
    │
    ▼
Kong Gateway (porta 8000)
    │
    ├── 1. Valida token JWT
    │     ├── Sem token ou inválido → 401 Unauthorized ❌
    │     └── Token válido → continua ✅
    │
    ├── 2. Verifica rate-limiting
    │     ├── Limite excedido → 429 Too Many Requests ❌
    │     └── Dentro do limite → continua ✅
    │
    ├── 3. Verifica CORS e tamanho do payload
    │     └── Payload > 10MB → 413 Payload Too Large ❌
    │
    └── 4. Roteia para o microsserviço correto
          ├── /users/*   → UsersAPI
          └── /catalog/* → CatalogAPI
```

### Plugins de Segurança

| Plugin | Proteção | Resposta |
|---|---|---|
| `jwt` | Token inválido ou ausente | `401 Unauthorized` |
| `rate-limiting` | Mais de 30 req/min ou 500/hora | `429 Too Many Requests` |
| `cors` | Controle de origens | bloqueio no navegador |
| `request-size-limiting` | Payload acima de 10MB | `413 Payload Too Large` |

### Estrutura dos Manifestos

```
k8s/kong/
├── kong-namespace.yaml    → namespace isolado para o Kong
├── kong-rbac.yaml         → permissões do Kong no cluster
├── kong-deployment.yaml   → Pod do Kong + variáveis de ambiente
├── kong-service.yaml      → portas externas do gateway
└── kong-config.yaml       → rotas, plugins e consumers
```

> 📖 Consulte o [Guia de Operação](k8s/kong/GUIA-OPERACAO-KONG.txt) para instruções detalhadas de como subir, testar e solucionar problemas do Kong.

### Portas do Kong

| Porta | Descrição | URL |
|---|---|---|
| `8000` | Proxy HTTP — entrada das requisições | `http://localhost:8000` |
| `8001` | Admin API — verificar configurações | `http://localhost:8001` |
| `8002` | Kong Manager OSS — interface web | `http://localhost:8002` |

### Como Testar o Gateway

**1. Subir o port-forward:**
```bash
kubectl port-forward service/kong-proxy 8000:80 -n kong
```

**2. Sem token (deve retornar 401):**
```bash
curl -X GET http://localhost:8000/users/api/Usuarios/BuscarPorId/{id}
```

**3. Com token válido (deve retornar dados):**
```bash
curl -X GET http://localhost:8000/users/api/Usuarios/BuscarPorId/{id} \
  -H "Authorization: Bearer SEU_TOKEN_AQUI"
```

> 💡 Gere o token via `POST http://localhost:5001/api/Authentication/login`

### Visualização via Konga (Opcional)

Para demonstração visual do Kong com interface gráfica completa:

```bash
cd kong-visual
docker compose up -d
```

Acesse o Konga em `http://localhost:1337` e conecte ao Kong usando `http://kong:8001`.

---

## 🚀 Como Rodar Localmente (Docker Compose)

### Pré-requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e rodando
- [Git](https://git-scm.com/) instalado

### 1. Clone os repositórios

Clone todos os repositórios na **mesma pasta pai**:

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
├── OrchestrationAPI/
│   ├── docker-compose.yml
│   ├── k8s/
│   └── kong-visual/
├── UsersAPI/
├── CatalogAPI/
├── PaymentsAPI/
└── NotificationsAPI/
```

### 2. Suba o ambiente

```bash
cd OrchestrationAPI
docker compose up --build
```

### 3. Aguarde a inicialização

```
users-api         | Application started. ✅
catalog-api       | Application started. ✅
payments-api      | Application started. ✅
notifications-api | Application started. ✅
```

---

## ☸️ Como Rodar com Kubernetes

### Pré-requisitos

- Docker Desktop com **Kubernetes habilitado**
- `kubectl` disponível no terminal
- Contexto ativo: `docker-desktop`

```bash
# Verificar contexto ativo
kubectl config get-contexts
```

### 1. Criar o namespace

```bash
kubectl create namespace fcg-fase3
```

### 2. Subir a infraestrutura

```bash
cd OrchestrationApi
kubectl apply -f k8s/ -n fcg-fase3
```

Aguarde todos ficarem `Running`:
```bash
kubectl get pods -n fcg-fase3 -w
```

### 3. Buildar as imagens dos microsserviços

```bash
docker build -t orchestrationapi-users-api:latest ../UsersAPI/
docker build -t orchestrationapi-catalog-api:latest ../CatalogAPI/
docker build -t orchestrationapi-payments-api:latest ../PaymentsAPI/
docker build -t orchestrationapi-notifications-api:latest ../NotificationsAPI/
```

### 4. Subir os microsserviços

```bash
kubectl apply -f ../UsersAPI/k8s/
kubectl apply -f ../CatalogAPI/k8s/
kubectl apply -f ../PaymentsAPI/k8s/
kubectl apply -f ../NotificationsAPI/k8s/
```

### 5. Subir o Kong API Gateway

```bash
kubectl apply -f k8s/kong/
```

Aguarde o Kong ficar `Running`:
```bash
kubectl get pods -n kong -w
```

### 6. Verificar se tudo está rodando

```bash
kubectl get pods
kubectl get pods -n kong
kubectl get services
```

### 7. Acessando os serviços

| Serviço | URL |
|---|---|
| Kong Gateway | `http://localhost:8000` (via port-forward) |
| Kong Admin API | `http://localhost:8001` (via port-forward) |
| Kong Manager | `http://localhost:8002` (via port-forward) |
| UsersAPI Swagger | `http://localhost:30001/swagger` |
| CatalogAPI Swagger | `http://localhost:30002/swagger` |
| PaymentsAPI Swagger | `http://localhost:30003/swagger` |
| NotificationsAPI Swagger | `http://localhost:30004/swagger` |
| RabbitMQ Management | `http://localhost:30072` |

---

## 🔐 Autenticação

**1. Cadastre um usuário:**
```bash
POST http://localhost:5001/api/Usuarios/Cadastrar
```

**2. Faça login:**
```bash
POST http://localhost:5001/api/Authentication/login
```

**3. Use o token nas requisições pelo Kong:**
```
Authorization: Bearer <seu_token>
```

---

## 🗃️ Bancos de Dados

| Serviço | Database |
|---|---|
| UsersAPI | `MS_UsersAPI` |
| CatalogAPI | `MS_CatalogAPI` |
| PaymentsAPI | `MS_PaymentAPI` |
| NotificationsAPI | `MS_NotificationsAPI` |

---

## 📦 Repositórios dos Microsserviços

| Serviço | Repositório |
|---|---|
| UsersAPI | https://github.com/marciotorquato/UsersAPI |
| CatalogAPI | https://github.com/marciotorquato/CatalogAPI |
| PaymentsAPI | https://github.com/marciotorquato/PaymentsAPI |
| NotificationsAPI | https://github.com/marciotorquato/NotificationsAPI |

---

## 🎓 Contexto Acadêmico

Projeto desenvolvido para o **Tech Challenge Fase 3** da pós-graduação **PosTech - Arquitetura de Software em .NET com Azure** da FIAP.

**Objetivo:** Profissionalizar a arquitetura de microsserviços aplicando API Gateway, Serverless, Observabilidade, Persistência Poliglota e Cache.
