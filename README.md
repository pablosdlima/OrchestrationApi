# 🎮 FCG - FIAP Cloud Games | OrchestrationAPI

Repositório de orquestração da arquitetura de microsserviços da **FIAP Cloud Games (FCG)**, desenvolvido como entregável do **Tech Challenge Fase 2 - PosTech FIAP**.

Este repositório contém o `docker-compose.yml` responsável por subir toda a infraestrutura e os 4 microsserviços da plataforma em ambiente local, e os manifestos Kubernetes (`/k8s`) para execução em cluster.

---

## 📐 Arquitetura

A plataforma FCG foi refatorada de um monolito para uma arquitetura de **microsserviços orientada a eventos**, utilizando RabbitMQ como broker de mensagens.

### Microsserviços

| Serviço | Responsabilidade | Porta (Docker) | Porta (Kubernetes) |
|---|---|---|---|
| **UsersAPI** | Cadastro e autenticação de usuários (JWT) | `5001` | `30001` |
| **CatalogAPI** | CRUD de jogos e início do fluxo de compra | `5002` | `30002` |
| **PaymentsAPI** | Processamento de pagamentos | `5003` | `30003` |
| **NotificationsAPI** | Envio de notificações por e-mail (log no console) | `5004` | `30004` |

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

## ☸️ Como Rodar com Kubernetes

### Pré-requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) com **Kubernetes habilitado**
- `kubectl` disponível no terminal

> Para habilitar o Kubernetes no Docker Desktop: **Settings → Kubernetes → Enable Kubernetes → Apply & Restart**

### Estrutura dos manifestos

```
OrchestrationAPI/
└── k8s/
    ├── sqlserver.yaml   ← SQL Server (PVC + Deployment + Service)
    ├── mongodb.yaml     ← MongoDB    (PVC + Deployment + Service)
    └── rabbitmq.yaml    ← RabbitMQ   (Deployment + Service)

UsersAPI/
└── k8s/
    ├── configmap.yaml   ← variáveis não sensíveis
    ├── secret.yaml      ← variáveis sensíveis (Base64)
    ├── deployment.yaml  ← gerencia os Pods
    └── service.yaml     ← expõe o serviço na rede

# (mesma estrutura para CatalogAPI, PaymentsAPI e NotificationsAPI)
```

### 1. Construa as imagens localmente

As imagens precisam existir localmente antes de aplicar os manifestos:

```bash
cd ../UsersAPI
docker build -t orchestrationapi-users-api:latest .

cd ../CatalogAPI
docker build -t orchestrationapi-catalog-api:latest .

cd ../PaymentsAPI
docker build -t orchestrationapi-payments-api:latest .

cd ../NotificationsAPI
docker build -t orchestrationapi-notifications-api:latest .
```

### 2. Suba a infraestrutura

```bash
cd OrchestrationAPI
kubectl apply -f k8s/
```

Aguarde os Pods ficarem prontos:

```bash
kubectl get pods -w
```

Espere até todos aparecerem como `Running`:

```
NAME                         READY   STATUS
sqlserver-xxx                1/1     Running
mongodb-xxx                  1/1     Running
rabbitmq-xxx                 1/1     Running
```

### 3. Suba os microsserviços

Execute em cada repositório, na seguinte ordem:

```bash
# 1. UsersAPI
cd ../UsersAPI
kubectl apply -f k8s/

# 2. CatalogAPI
cd ../CatalogAPI
kubectl apply -f k8s/

# 3. PaymentsAPI
cd ../PaymentsAPI
kubectl apply -f k8s/

# 4. NotificationsAPI
cd ../NotificationsAPI
kubectl apply -f k8s/
```

### 4. Verifique se tudo está rodando

```bash
kubectl get pods
kubectl get services
```

### 5. Acessando os serviços no Kubernetes

| Serviço | URL |
|---|---|
| UsersAPI Swagger | http://localhost:30001/swagger |
| CatalogAPI Swagger | http://localhost:30002/swagger |
| PaymentsAPI Swagger | http://localhost:30003/swagger |
| NotificationsAPI Swagger | http://localhost:30004/swagger |
| RabbitMQ Management | http://localhost:30072 |

> ⚠️ **Atenção:** O Docker Desktop pode atribuir portas diferentes das definidas nos manifestos. Se a URL não abrir, verifique a porta real com `kubectl get services` e use a porta listada na coluna `PORT(S)`.

### Parando o ambiente Kubernetes

```bash
# Remove os microsserviços
kubectl delete -f ../UsersAPI/k8s/
kubectl delete -f ../CatalogAPI/k8s/
kubectl delete -f ../PaymentsAPI/k8s/
kubectl delete -f ../NotificationsAPI/k8s/

# Remove a infraestrutura
kubectl delete -f k8s/
```

---

## 🛠️ Guia de Operação do Kubernetes

Após o ambiente estar rodando, use os comandos abaixo para monitorar e operar o cluster.

### Verificar status dos Pods

```bash
# Lista todos os Pods e seus status
kubectl get pods

# Fica assistindo em tempo real (Ctrl+C para sair)
kubectl get pods -w
```

Os status possíveis são:

| Status | Significado |
|---|---|
| `Pending` | Kubernetes está preparando o Pod |
| `ContainerCreating` | Container sendo criado |
| `Running` | Pod rodando normalmente ✅ |
| `CrashLoopBackOff` | Pod travando repetidamente ❌ |
| `Error` | Pod encerrou com erro ❌ |

### Ver logs de um Pod

```bash
# Ver logs de um Pod específico (substitua pelo nome real do Pod)
kubectl logs users-api-xxx

# Seguir os logs em tempo real
kubectl logs -f users-api-xxx

# Ver os logs do Pod anterior (útil quando o Pod reiniciou)
kubectl logs users-api-xxx --previous
```

> 💡 Para descobrir o nome exato do Pod, rode `kubectl get pods` primeiro.

### Reiniciar um Pod

O Kubernetes não tem um comando direto de restart. A forma correta é deletar o Pod — o Deployment sobe um novo automaticamente:

```bash
# Deleta o Pod (o Deployment cria um novo em segundos)
kubectl delete pod users-api-xxx

# Ou reinicia o Deployment inteiro (todos os Pods dele)
kubectl rollout restart deployment users-api
```

### Escalar réplicas

```bash
# Escala a UsersAPI para 3 réplicas
kubectl scale deployment users-api --replicas=3

# Volta para 1 réplica
kubectl scale deployment users-api --replicas=1

# Verifica as réplicas rodando
kubectl get pods
```

> ℹ️ Escalar significa ter mais cópias do mesmo serviço rodando ao mesmo tempo, distribuindo a carga entre elas.

### Acessar o Swagger após subir

1. Verifique as portas reais dos serviços:
```bash
kubectl get services
```

2. Na coluna `PORT(S)`, localize a porta externa do serviço desejado:
```
users-api-service   NodePort   ...   80:32301/TCP
#                                        ↑ essa é a porta externa
```

3. Acesse no browser:
```
http://localhost:32301/swagger
```

---

## 🌐 Acessando os Serviços (Docker Compose)

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

1. Acesse o Swagger da **UsersAPI**
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

### Connection Strings

| Ambiente | Connection String |
|---|---|
| **Docker Compose** | `Server=sqlserver,1433;User Id=sa;Password=Senha@123;TrustServerCertificate=True` |
| **Kubernetes (interno)** | `Server=sqlserver-service,1433;User Id=sa;Password=Senha@123;TrustServerCertificate=True` |

> ℹ️ No Kubernetes, os microsserviços se comunicam com o SQL Server pelo nome do Service (`sqlserver-service`). Acesso externo via SSMS ou Azure Data Studio requer expor o serviço como `NodePort`.

### Acessando o SQL Server externamente (Kubernetes)

Por padrão o SQL Server no Kubernetes está configurado como `ClusterIP` — acessível apenas dentro do cluster. Para acessar externamente via SSMS ou Azure Data Studio, use o `port-forward`:

```bash
# Descobre o nome do Pod do SQL Server
kubectl get pods

# Cria um túnel temporário
kubectl port-forward pod/sqlserver-xxx 1433:1433
```

Enquanto o comando estiver rodando, acesse pelo SSMS:
```
Servidor:  localhost,1433
Usuário:   sa
Senha:     Senha@123
```

---

## ⚙️ Variáveis de Ambiente

### 🗄️ SQL Server

| Variável | Valor | Usado em |
|---|---|---|
| `SA_PASSWORD` | `Senha@123` | Senha do usuário administrador do SQL Server |
| `SA_USER` | `sa` | Usuário administrador do SQL Server |
| `ACCEPT_EULA` | `Y` | Aceite obrigatório da licença Microsoft do SQL Server |

### 🍃 MongoDB

| Variável | Valor | Usado em |
|---|---|---|
| `MONGO_INITDB_ROOT_USERNAME` | `root` | Usuário administrador do MongoDB |
| `MONGO_INITDB_ROOT_PASSWORD` | `root` | Senha do administrador do MongoDB |

### 🐇 RabbitMQ

| Variável | Valor | Usado em |
|---|---|---|
| `RabbitMQ__Username` | `admin` | Usuário de conexão ao RabbitMQ — usado por todos os microsserviços |
| `RabbitMQ__Password` | `admin` | Senha de conexão ao RabbitMQ — usado por todos os microsserviços |

### 🔐 JWT

| Variável | Valor | Usado em |
|---|---|---|
| `Jwt__Key` | `af3b1d967c45e0df2b84...` | Chave de assinatura dos tokens JWT — UsersAPI e CatalogAPI |
| `Jwt__Issuer` | `UserAPI` / `CatalogAPI` | Identificador de quem emitiu o token — varia por serviço |
| `Jwt__Audience` | `https://api.UserAPI.com` | Para quem o token é válido — varia por serviço |

### 📋 Serilog (Logs)

| Variável | Valor | Usado em |
|---|---|---|
| `Serilog__WriteTo__0__Args__databaseUrl` | `mongodb://root:root@mongodb:27017/logs_dev` | URL de conexão ao MongoDB para gravação de logs — usado por todos os microsserviços |

> ⚠️ Estes valores são apenas para desenvolvimento local. Em produção, utilize variáveis de ambiente seguras ou um cofre de segredos (ex: Azure Key Vault).

---

## 🛑 Parando o Ambiente (Docker Compose)

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
| UsersAPI | https://github.com/marciotorquato/UsersAPI |
| CatalogAPI | https://github.com/marciotorquato/CatalogAPI |
| PaymentsAPI | https://github.com/marciotorquato/PaymentsAPI |
| NotificationsAPI | https://github.com/marciotorquato/NotificationsAPI |

---

## 📸 Ambiente Rodando

Todos os containers em execução via Docker Desktop:

![Docker Desktop - Todos os containers no ar](./assets/Captura_de_tela_2026-03-08_134004.png)

---

## 📸 Ambiente Rodando - Kubernetes

![Kubernetes - Todos os Pods no ar](./assets/Captura_de_tela_2026-03-11_194700.png)

---

## 🎓 Contexto Acadêmico

Projeto desenvolvido para o **Tech Challenge Fase 2** da pós-graduação **PosTech - Arquitetura de Software em .NET com Azure** da FIAP.

**Objetivo:** Refatorar o MVP monolítico da FIAP Cloud Games em uma arquitetura de microsserviços orientada a eventos, aplicando os conceitos estudados na Fase 2.