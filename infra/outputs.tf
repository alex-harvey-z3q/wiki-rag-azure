output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "container_app_environment_name" {
  value = azurerm_container_app_environment.this.name
}

output "acr_name" {
  value = azurerm_container_registry.this.name
}

output "acr_login_server" {
  value = azurerm_container_registry.this.login_server
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "raw_container_name" {
  value = azurerm_storage_container.raw.name
}

output "parsed_container_name" {
  value = azurerm_storage_container.parsed.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgres_admin_username" {
  value = local.db_username
}

output "kv_reader_identity_id" {
  value = azurerm_user_assigned_identity.kv_reader.id
}

output "kv_reader_principal_id" {
  value = azurerm_user_assigned_identity.kv_reader.principal_id
}

output "github_actions_client_id" {
  value = azuread_application.github_actions.client_id
}

output "github_actions_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "github_actions_subscription_id" {
  value = data.azurerm_subscription.current.subscription_id
}
