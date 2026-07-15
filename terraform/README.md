# Infraestrutura Azure (Fase 4) — AKS, ACR, OIDC — 100% Free Tier

Provisiona a infraestrutura Cloud-Native exigida pelo Tech Challenge Fase 4, desenhada especificamente para caber no free tier da conta Azure (Free Trial):

- **Resource Group + VNet** — sempre gratuitos.
- **AKS** (`sku_tier = "Free"`) — control plane sempre gratuito; node pool com `Standard_B2pts_v2` (única VM do free tier disponível pra essa assinatura em `westus2`, confirmada via `az vm list-skus`).
- **Azure Container Registry** (nível Standard) — 100GB grátis por 12 meses.
- **Load Balancer Standard** — criado automaticamente pelo AKS quando um Service `LoadBalancer` é aplicado; 750h/mês grátis por 12 meses.
- **Federação OIDC do GitHub Actions** — os workflows autenticam sem senha/secret fixo.

## ⚠️ O único item que não está 100% coberto pela tabela de free tier

O **Public IP** (endereço IP público) que o Load Balancer usa não aparece como linha separada na tabela de serviços gratuitos da Azure — só o "Load Balancer" em si está listado. Na prática o custo de um Public IP Standard é pequeno (poucos centavos por hora), e fica coberto pelos US$ 200 de crédito enquanto ele durar. Sendo transparente: esse é o único ponto que tecnicamente pode gerar uma cobrança mínima fora da tabela que você me mostrou — mas nunca vai ser significativo dentro do padrão "sobe pra sessão, derruba depois".

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- Azure CLI já logado (`az login`) — confirmado
- `kubectl`

## Passo a passo

### 1. Configurar variáveis

```powershell
cd OrchestrationApi/terraform
copy terraform.tfvars.example terraform.tfvars
```

Os valores padrão já batem com o que confirmamos (subscription id, `westus2`, `Standard_B2pts_v2`). Só ajuste `acr_name` se o nome já estiver em uso por outra conta Azure (o nome do ACR é global).

### 2. Provisionar

```powershell
terraform init
terraform plan
terraform apply
```

### 3. Configurar o GitHub Actions

```powershell
terraform output
```

No GitHub, em **cada** repositório (`UsersAPI` e `CatalogAPI`) → *Settings → Secrets and variables → Actions*, cadastre como **Variables** (não precisam ser secretas — são identificadores, não senhas):

| Nome | Valor (vem do output) |
|---|---|
| `AZURE_CLIENT_ID` | `github_actions_client_id` |
| `AZURE_TENANT_ID` | `azure_tenant_id` |
| `AZURE_SUBSCRIPTION_ID` | `azure_subscription_id` |
| `ACR_LOGIN_SERVER` | `acr_login_server` |
| `AKS_CLUSTER_NAME` | `cluster_name` |
| `AKS_RESOURCE_GROUP` | `resource_group_name` |

### 4. Bootstrap inicial do cluster

```powershell
az aks get-credentials --resource-group fcg-rg --name fcg-aks-cluster
kubectl get nodes
```

A partir daqui, aplique os manifestos base normalmente (`kubectl apply -f ...`) antes do primeiro deploy via pipeline.

## Disciplina de custo — leia antes de deixar rodando

O free tier da VM (`Standard_B2pts_v2`) dá **750 horas/mês**. Com `node_count = 2`, isso dura **~15 dias corridos** se ficar ligado o tempo todo. Para não gastar à toa:

```powershell
# No fim de cada sessão de trabalho
terraform destroy

# No início da próxima sessão
terraform apply
```

Reserve o cluster ligado continuamente só perto da apresentação (gravação do vídeo + demonstração ao vivo).

## Destruir tudo

```powershell
terraform destroy
```
