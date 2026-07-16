variable "subscription_id" {
  description = "Subscription ID da conta Azure (Free Trial). Sem default de propósito — preencha via terraform.tfvars (fora do git) ou variável de ambiente TF_VAR_subscription_id."
  type        = string
}

variable "location" {
  description = "Região do Azure (westus2 já confirmada como funcional pro cluster)"
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

# ─── Node pool (pago) ───────────────────────────────────────────────
# O AKS bloqueia VMs do free tier (Standard_B2pts_v2/B2ats_v2, 2 vCPU/
# 4GB) em qualquer pool — erro VMSizeRestrictedByAKS, confirmado na
# prática. Standard_D2s_v3 é a menor VM viável (2 vCPU/8GB,
# ~US$0,10/hora). Recomendado: subir só durante as sessões de trabalho
# e destruir depois (terraform destroy) pra minimizar o custo.
variable "node_vm_size" {
  description = "Tamanho da VM do node pool do AKS (precisa ser maior que o free tier — bloqueado pela própria AKS)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "node_count" {
  description = "Quantidade de nodes do AKS (2 dá margem de recursos pro stack completo)"
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
