output "resource_group_name" {
  description = "Nome do Resource Group"
  value       = azurerm_resource_group.this.name
}

output "cluster_name" {
  description = "Nome do cluster AKS"
  value       = azurerm_kubernetes_cluster.this.name
}

output "location" {
  description = "Região usada"
  value       = var.location
}

output "acr_login_server" {
  description = "URL do registry (usar como base da tag da imagem Docker)"
  value       = azurerm_container_registry.this.login_server
}

output "acr_name" {
  description = "Nome do Container Registry"
  value       = azurerm_container_registry.this.name
}

output "github_actions_client_id" {
  description = "Client ID (Application ID) usado no login OIDC do GitHub Actions (AZURE_CLIENT_ID)"
  value       = azuread_application.github_actions.client_id
}

output "azure_tenant_id" {
  description = "Tenant ID da Azure (AZURE_TENANT_ID)"
  value       = data.azurerm_client_config.current.tenant_id
}

output "azure_subscription_id" {
  description = "Subscription ID (AZURE_SUBSCRIPTION_ID)"
  value       = var.subscription_id
}
