# Infraestrutura Azure (Fase 4) — AKS, ACR, OIDC

Provisiona a infraestrutura Cloud-Native exigida pelo Tech Challenge Fase 4:

- **Resource Group + VNet** — sempre gratuitos.
- **AKS** (`sku_tier = "Free"`) — control plane sempre gratuito. Node pool único com **`Standard_D2s_v3`** (2 vCPU/8GB, ~US$0,10/hora/node).
- **Azure Container Registry** (nível Standard) — 100GB grátis por 12 meses.
- **Load Balancer Standard** — criado automaticamente pelo AKS quando um Service `LoadBalancer` é aplicado; 750h/mês grátis por 12 meses.
- **Federação OIDC do GitHub Actions** — os workflows autenticam sem senha/secret fixo.

## ⚠️ Por que não é 100% free tier

Tentamos rodar os nodes do AKS nas VMs do free tier (`Standard_B2pts_v2`/`B2ats_v2`, 2 vCPU/4GB) e batemos em duas travas da própria plataforma, na ordem:

1. `SystemPoolSkuTooLow` — o pool de sistema exige VM com mais de 2 vCPU/4GB.
2. Depois de isolar um pool de sistema pago à parte, o pool de usuário com a VM do free tier ainda falhou com `VMSizeRestrictedByAKS` — a AKS bloqueia essas VMs pequenas em **qualquer** pool, não só no de sistema.

Conclusão: não tem contorno de configuração — a AKS simplesmente não aceita as VMs do free tier em nenhum lugar. A solução foi usar `Standard_D2s_v3` (a menor VM viável) em um único pool.

**Custo estimado** (2 nodes `Standard_D2s_v3`, ~US$0,20/hora combinado):

| Cenário | Cálculo | Total |
|---|---|---|
| Uso disciplinado (~40h até a apresentação) | 40h × ~US$0,20/h | **~US$ 8** |
| Pior caso (esquecido ligado 24/7 por 2 semanas, 336h) | 336h × ~US$0,20/h | **~US$ 67** |

Sai do crédito de US$ 200 (Free Trial), não de uma cota de free tier — mesmo no pior caso, fica bem abaixo do disponível. Além disso, o **Public IP** do Load Balancer também não é coberto pela tabela de free tier (custo de poucos centavos/hora), mas é insignificante perto do valor acima.

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

Preencha o `subscription_id` no `terraform.tfvars` (pegue com `az account show --query id -o tsv`). Os demais valores padrão já refletem o que confirmamos. Só ajuste `acr_name` se o nome já estiver em uso por outra conta Azure (o nome do ACR é global).

### 2. Provisionar

```powershell
terraform init
terraform plan
terraform apply
```

A criação do AKS leva uns 5 minutos.

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

Devem aparecer **2 nodes**, ambos `Standard_D2s_v3`, com `STATUS: Ready`.

A partir daqui, aplique os manifestos base normalmente (`kubectl apply -f ...`) antes do primeiro deploy via pipeline.

## Disciplina de custo — leia antes de deixar rodando

Como agora **todo** o node pool é pago (~US$0,20/hora combinado), a disciplina de ligar/desligar importa mais do que antes:

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
