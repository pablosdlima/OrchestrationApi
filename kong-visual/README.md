# Kong Visual — Ambiente de Demonstração

> ⚠️ **Atenção:** Este ambiente é exclusivo para **demonstração visual** do Kong via Konga.
> O ambiente oficial do projeto roda no Kubernetes (`k8s/kong/`).

---

## O que é este ambiente?

O Kong em modo **DB-less** (usado no Kubernetes) não exibe configurações
corretamente no Konga ou Kong Manager. Este Docker Compose sobe o Kong
em modo **DB com PostgreSQL**, permitindo visualização completa via Konga.

---

## Serviços

| Serviço | Descrição | URL |
|---|---|---|
| Kong Proxy | Entrada das requisições | http://localhost:8000 |
| Kong Admin API | Gerenciamento via REST | http://localhost:8001 |
| Kong Manager OSS | Interface web do Kong | http://localhost:8002 |
| Konga | Interface visual completa | http://localhost:1337 |
| PostgreSQL | Banco de dados | porta 5432 |

---

## Como subir

```bash
cd OrchestrationApi/kong-visual
docker compose up -d
```

Aguarde todos os containers ficarem prontos:

```bash
docker compose ps
```

---

## Configurar o Konga

1. Acesse **http://localhost:1337**
2. Crie um usuário admin na primeira vez
3. Clique em **Connections** → **New Connection**
4. Preencha:
   - Name: `FCG Kong`
   - Kong Admin URL: `http://kong:8001`
5. Clique em **Activate**

Agora você tem acesso visual completo ao Kong! 🎉

---

## Configurar rotas no Konga

Após conectar, adicione os serviços e rotas:

### UsersAPI
- **Services** → Add Service
  - Name: `users-api`
  - URL: `http://host.docker.internal:30001`

- **Routes** → Add Route
  - Name: `users-api-route`
  - Paths: `/users`

### CatalogAPI
- **Services** → Add Service
  - Name: `catalog-api`
  - URL: `http://host.docker.internal:30002`

- **Routes** → Add Route
  - Name: `catalog-api-route`
  - Paths: `/catalog`

---

## Como parar

```bash
docker compose down

# Para remover os dados do banco também:
docker compose down -v
```