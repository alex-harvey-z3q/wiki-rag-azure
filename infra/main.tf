resource "azurerm_resource_group" "this" {
  name     = "${local.project}-rg"
  location = local.location
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.project}-law"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "this" {
  name                       = "${local.project}-env"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_storage_account" "this" {
  name                     = "wikirag${substr(replace(uuid(), "-", ""), 0, 10)}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "raw" {
  name                  = "raw"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "parsed" {
  name                  = "parsed"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_container_registry" "this" {
  name                = "wikiragacr${substr(replace(uuid(), "-", ""), 0, 8)}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = true
}

data "azurerm_key_vault" "this" {
  name                = local.key_vault_name
  resource_group_name = local.key_vault_rg_name
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  key_vault_id = data.azurerm_key_vault.this.id
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                   = "${local.project}-pg"
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  version                = "15"
  administrator_login    = local.db_username
  administrator_password = data.azurerm_key_vault_secret.db_password.value
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
  zone                   = "1"
}

resource "azurerm_user_assigned_identity" "kv_reader" {
  name                = "${local.project}-kv-reader"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_assignment" "kv_reader_secrets_user" {
  scope                = data.azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.kv_reader.principal_id
}
