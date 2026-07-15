variable "subscription_id" {
  description = "Subscription ID da conta Azure (Free Trial). Sem default de propósito — preencha via terraform.tfvars (fora do git) ou variável de ambiente TF_VAR_subscription_id."
  type        = string
}

variable "location" {
  description = "Região do Azure — precisa ter a VM Standard_B2pts_v2 disponível (confirmado em westus2)"
  type        = string
  default     = "westus2"
}

variable "environment" {
  description = "Nome do ambiente (usado em tags)"
  type        = string
  default     = "production"
}

variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
  default     = "fcg-rg"
}

variable "cluster_name" {
  description = "Nome do cluster AKS"
  type        = string
  default     = "fcg-aks-cluster"
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes no AKS (null = a padrão mais recente suportada pela região)"
  type        = string
  default     = null
}

variable "vnet_cidr" {
  description = "CIDR block da VNet do cluster"
  type        = string
  default     = "10.42.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block da subnet dos nodes do AKS"
  type        = string
  default     = "10.42.1.0/24"
}

# ─── Pool de sistema (pago, mínimo) ────────────────────────────────
# O AKS exige mais de 2 vCPUs/4GB no pool de sistema — nenhuma VM do
# free tier atende. Standard_D2s_v3 é uma VM genérica pequena e barata
# (~US$0,10/hora), usada só pelos componentes internos do Kubernetes.
variable "system_node_vm_size" {
  description = "Tamanho da VM do pool de sistema do AKS (precisa ser > 2 vCPU/4GB — fora do free tier)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_count" {
  description = "Quantidade de nodes do pool de sistema (mantenha em 1 pra minimizar o custo pago)"
  type        = number
  default     = 1
}

# ─── Pool de usuário (free tier) ───────────────────────────────────
# Standard_B2pts_v2 é a única VM do free tier disponível pra essa
# assinatura na região westus2 (Standard_B2ats_v2 veio restrito). É
# aqui que a aplicação de verdade roda (Kong, UsersAPI, CatalogAPI,
# bancos etc). Recomendado: subir só durante as sessões de trabalho e
# destruir depois (terraform destroy).
variable "node_vm_size" {
  description = "Tamanho da VM do pool de usuário do AKS (onde a aplicação roda)"
  type        = string
  default     = "Standard_B2pts_v2"
}

variable "node_count" {
  description = "Quantidade de nodes do pool de usuário (2 dá mais margem de recursos pro stack completo; 1 economiza mais horas do free tier)"
  type        = number
  default     = 2
}

# ─── ACR ────────────────────────────────────────────────────────────
variable "acr_name" {
  description = "Nome do Azure Container Registry (precisa ser globalmente único, só letras/números)"
  type        = string
  default     = "fcgacr"
}

# ─── GitHub Actions OIDC ──────────────────────────────────────────────
variable "github_repositories" {
  description = "Repositórios autorizados a assumir a identidade via OIDC (formato org/repo)"
  type        = list(string)
  default = [
    "marciotorquato/UsersAPI",
    "marciotorquato/CatalogAPI",
  ]
}
