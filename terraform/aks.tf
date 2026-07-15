resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  sku_tier = "Free"

  # ─── Pool de sistema (pago, mínimo) ──────────────────────────────
  # O AKS exige que o pool de sistema use uma VM com MAIS de 2 vCPUs e
  # 4GB de memória (erro "SystemPoolSkuTooLow") — nenhuma VM do free
  # tier (B2pts_v2/B2ats_v2, ambas exatamente 2 vCPU/4GB) atende essa
  # exigência. Por isso esse pool usa uma VM pequena e paga, só o
  # suficiente pros componentes internos do Kubernetes (coredns,
  # metrics-server etc). "only_critical_addons_enabled" garante que
  # NENHUM pod da aplicação seja agendado aqui — só componentes
  # críticos do sistema — mantendo esse pool com o menor node_count
  # possível (1) e, consequentemente, o menor custo possível.
  default_node_pool {
    name                        = "system"
    vm_size                     = var.system_node_vm_size
    node_count                  = var.system_node_count
    vnet_subnet_id              = azurerm_subnet.aks.id
    only_critical_addons_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
    load_balancer_sku = "standard" # bate com o item "Standard Load Balancer" do free tier
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  role_based_access_control_enabled = true

  tags = {
    Project     = "FIAP Cloud Games"
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

# ─── Pool de usuário (free tier) ────────────────────────────────────
# Aqui é onde a aplicação de verdade roda (Kong, UsersAPI, CatalogAPI,
# SQL Server, MongoDB, Redis, RabbitMQ) — usando a VM Standard_B2pts_v2,
# a única do free tier disponível pra essa assinatura em westus2.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.node_vm_size
  node_count            = var.node_count
  vnet_subnet_id         = azurerm_subnet.aks.id
  mode                   = "User"
}

resource "azurerm_role_assignment" "current_user_aks_rbac_admin" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
