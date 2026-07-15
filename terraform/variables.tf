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

variable "node_vm_size" {
  description = "Tamanho da VM do node pool do AKS"
  type        = string
  default     = "Standard_B2pts_v2"
}

variable "node_count" {
  description = "Quantidade de nodes do AKS (2 dá mais margem de recursos pro stack completo; 1 economiza mais horas do free tier)"
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
