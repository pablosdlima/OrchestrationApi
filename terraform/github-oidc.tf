resource "azuread_application" "github_actions" {
  display_name = "${var.cluster_name}-github-actions"
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
}

resource "azuread_application_federated_identity_credential" "github_actions" {
  for_each = toset(var.github_repositories)

  application_id = azuread_application.github_actions.id
  display_name   = "github-${replace(each.value, "/", "-")}-main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${each.value}:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "github_actions_acr_push" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_aks_user" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.github_actions.object_id
}

resource "azurerm_role_assignment" "github_actions_aks_rbac_admin" {
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azuread_service_principal.github_actions.object_id
}
