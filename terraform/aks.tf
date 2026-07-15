resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  sku_tier = "Free"

  default_node_pool {
    name           = "default"
    vm_size        = var.node_vm_size
    node_count     = var.node_count
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
    load_balancer_sku = "standard" # bate com o item "Standard Load Balancer" do free tier
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
  }

  role_based_access_control_enabled = true

  tags = {
    Project     = "FIAP Cloud Games"
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

resource "azurerm_role_assignment" "current_user_aks_rbac_admin" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
