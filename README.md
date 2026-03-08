# 🎮 FCG - FIAP Cloud Games | OrchestrationAPI

Repositório de orquestração da arquitetura de microsserviços da **FIAP Cloud Games (FCG)**, desenvolvido como entregável do **Tech Challenge Fase 2 - PosTech FIAP**.

Este repositório contém o `docker-compose.yml` responsável por subir toda a infraestrutura e os 4 microsserviços da plataforma em ambiente local.

---

## 📐 Arquitetura

A plataforma FCG foi refatorada de um monolito para uma arquitetura de **microsserviços orientada a eventos**, utilizando RabbitMQ como broker de mensagens.

### Microsserviços

| Serviço | Responsabilidade | Porta |
|---|---|---|
| **UsersAPI** | Cadastro e autenticação de usuários (JWT) | `5001` |
| **CatalogAPI** | CRUD de jogos e início do fluxo de compra | `5002` |
| **PaymentsAPI** | Processamento de pagamentos | `5003` |
| **NotificationsAPI** | Envio de notificações por e-mail (log no console) | `5004` |

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

### Infraestrutura

| Serviço | Descrição | Porta |
|---|---|---|
| **SQL Server 2022** | Banco de dados relacional (1 instância, 4 databases) | `1433` |
| **MongoDB 7** | Armazenamento de logs (Serilog) | `27017` |
| **Mongo Express** | Interface web para o MongoDB | `8081` |
| **RabbitMQ** | Broker de mensagens + Management UI | `5672` / `15672` |

---

## 🚀 Como Rodar Localmente

### Pré-requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e rodando
- [Git](https://git-scm.com/) instalado

### 1. Clone os repositórios

Clone todos os repositórios na **mesma pasta pai**:

```bash
git clone https://github.com/seu-usuario/OrchestrationAPI
git clone https://github.com/seu-usuario/UsersAPI
git clone https://github.com/seu-usuario/CatalogAPI
git clone https://github.com/seu-usuario/PaymentsAPI
git clone https://github.com/seu-usuario/NotificationsAPI
```

A estrutura de pastas deve ficar assim:

```
Projeto/
├── OrchestrationAPI/     ← este repositório
│   └── docker-compose.yml
├── UsersAPI/
├── CatalogAPI/
├── PaymentsAPI/
└── NotificationsAPI/
```

> ⚠️ **Importante:** Os repositórios precisam estar na mesma pasta pai, pois o `docker-compose.yml` referencia os outros serviços com caminhos relativos (`../UsersAPI`, `../CatalogAPI`, etc).

### 2. Suba o ambiente

```bash
cd OrchestrationAPI
docker compose up --build
```

O Docker irá:
1. Baixar as imagens base (.NET 9, SQL Server, MongoDB, RabbitMQ)
2. Compilar e publicar os 4 microsserviços
3. Subir todos os containers
4. Aplicar as migrations automaticamente em cada banco de dados
5. Inicializar os consumers do RabbitMQ

### 3. Aguarde a inicialização

O ambiente está pronto quando você ver no log:

```
users-api         | Application started.
catalog-api       | Application started.
payments-api      | Application started.
notifications-api | Application started.
```

> ℹ️ O RabbitMQ pode demorar alguns segundos para ficar disponível. Os serviços têm retry automático — caso algum falhe na conexão inicial, ele tentará novamente automaticamente.

---

## 🌐 Acessando os Serviços

### Swagger (documentação dos endpoints)

| Serviço | URL |
|---|---|
| UsersAPI | http://localhost:5001/swagger |
| CatalogAPI | http://localhost:5002/swagger |
| PaymentsAPI | http://localhost:5003/swagger |
| NotificationsAPI | http://localhost:5004/swagger |

### Ferramentas de infraestrutura

| Ferramenta | URL | Credenciais |
|---|---|---|
| RabbitMQ Management | http://localhost:15672 | `admin` / `admin` |
| Mongo Express | http://localhost:8081 | `admin` / `admin` |

---

## 🔐 Autenticação

Os endpoints protegidos utilizam **JWT Bearer Token**.

### Passo a passo para autenticar no Swagger:

1. Acesse o Swagger da **UsersAPI** → `http://localhost:5001/swagger`
2. Crie um usuário via `POST /api/usuarios/cadastrar`
3. Faça login via `POST /api/auth/login` e copie o token retornado
4. Em qualquer Swagger, clique em **Authorize** 🔒
5. Digite `Bearer <seu_token>` e clique em **Authorize**

---

## 🗃️ Bancos de Dados

Cada microsserviço possui seu próprio banco no SQL Server:

| Serviço | Database |
|---|---|
| UsersAPI | `MS_UsersAPI` |
| CatalogAPI | `MS_CatalogAPI` |
| PaymentsAPI | `MS_PaymentAPI` |
| NotificationsAPI | `MS_NotificationsAPI` |

As migrations são aplicadas automaticamente na inicialização de cada serviço.

---

## ⚙️ Variáveis de Ambiente

As variáveis são configuradas diretamente no `docker-compose.yml`. Os valores padrão para ambiente de desenvolvimento são:

| Variável | Valor |
|---|---|
| `SA_PASSWORD` | `Senha@123` |
| `RabbitMQ__Username` | `admin` |
| `RabbitMQ__Password` | `admin` |
| `Jwt__Key` | `af3b1d967c45e0df2b84ca91fe3a9d6f1148e2c0e9b7d04a51f396cb8f0a7d32` |

> ⚠️ Estes valores são apenas para desenvolvimento local. Em produção, utilize variáveis de ambiente seguras ou um cofre de segredos (ex: Azure Key Vault).

---

## 🛑 Parando o Ambiente

```bash
# Para os containers mantendo os dados
docker compose down

# Para os containers e remove os volumes (apaga os dados)
docker compose down -v
```

---

## 📦 Repositórios dos Microsserviços

| Serviço | Repositório |
|---|---|
| UsersAPI | https://github.com/seu-usuario/UsersAPI |
| CatalogAPI | https://github.com/seu-usuario/CatalogAPI |
| PaymentsAPI | https://github.com/seu-usuario/PaymentsAPI |
| NotificationsAPI | https://github.com/seu-usuario/NotificationsAPI |

---

## 📸 Ambiente Rodando

Todos os 8 containers em execução via Docker Desktop:

![Docker Desktop - Todos os containers no ar](./assets/Captura_de_tela_2026-03-08_134004.png)

## 🎓 Contexto Acadêmico

Projeto desenvolvido para o **Tech Challenge Fase 2** da pós-graduação **PosTech - Arquitetura de Software em .NET com Azure** da FIAP.

**Objetivo:** Refatorar o MVP monolítico da FIAP Cloud Games em uma arquitetura de microsserviços orientada a eventos, aplicando os conceitos estudados na Fase 2.
