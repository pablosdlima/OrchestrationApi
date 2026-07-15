# Infraestrutura Azure (Fase 4) — AKS, ACR, OIDC — free tier + fatia mínima paga

Provisiona a infraestrutura Cloud-Native exigida pelo Tech Challenge Fase 4, desenhada pra ficar o mais próximo possível de 100% free tier na conta Azure (Free Trial):

- **Resource Group + VNet** — sempre gratuitos.
- **AKS** (`sku_tier = "Free"`) — control plane sempre gratuito. **Dois node pools**:
  - **Pool de sistema** (`system`, 1 node `Standard_D2s_v3`) — **pago** (~US$0,10/hora). O AKS exige VM com mais de 2 vCPU/4GB pro pool de sistema, e nenhuma VM do free tier atende isso — descobrimos na prática, com o erro `SystemPoolSkuTooLow`. Esse pool só roda componentes internos do Kubernetes (`only_critical_addons_enabled = true` impede qualquer pod da aplicação de cair aqui).
  - **Pool de usuário** (`user`, 2 nodes `Standard_B2pts_v2`) — **free tier**, única VM do free tier disponível pra essa assinatura em `westus2` (confirmada via `az vm list-skus`). É aqui que a aplicação de verdade roda (Kong, UsersAPI, CatalogAPI, bancos etc).
- **Azure Container Registry** (nível Standard) — 100GB grátis por 12 meses.
- **Load Balancer Standard** — criado automaticamente pelo AKS quando um Service `LoadBalancer` é aplicado; 750h/mês grátis por 12 meses.
- **Federação OIDC do GitHub Actions** — os workflows autenticam sem senha/secret fixo.

## ⚠️ Itens que não são 100% free tier

1. **Pool de sistema (`Standard_D2s_v3`)** — é o item de custo real, ~US$0,10/hora, inevitável (limitação da própria plataforma AKS, não uma escolha nossa). Em uso disciplinado (só durante sessões de trabalho) fica na faixa de **US$ 5 ou menos** até a apresentação; mesmo esquecido ligado 24/7 por 2 semanas, fica em ~US$ 34 — bem abaixo do crédito disponível.
2. **Public IP do Load Balancer** — não aparece como linha separada na tabela de free tier (só "Load Balancer" está listado). Custo de poucos centavos por hora, também coberto pelo crédito.

Ambos saem do crédito de US$ 200, não da cota do free tier — e juntos não chegam perto de esgotá-lo dentro do prazo do projeto.

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

Devem aparecer **3 nodes**: 1 do pool `system` (`Standard_D2s_v3`, pago) e 2 do pool `user` (`Standard_B2pts_v2`, free tier — é ali que os manifestos da aplicação devem ser agendados).

A partir daqui, aplique os manifestos base normalmente (`kubectl apply -f ...`) antes do primeiro deploy via pipeline.

## Disciplina de custo — leia antes de deixar rodando

O pool de sistema (`Standard_D2s_v3`) é pago o tempo todo que ficar ligado (~US$0,10/hora) — é o único item que realmente conta pro seu crédito. O pool de usuário (`Standard_B2pts_v2`) tem **750 horas/mês grátis**; com `node_count = 2`, esse orçamento dura ~15 dias corridos se ficar ligado sem parar (mas mesmo estourando, o custo adicional dessa parte seria mínimo). Para não gastar à toa:

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
