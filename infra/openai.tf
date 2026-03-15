resource "azurerm_cognitive_account" "openai" {
  name                = local.azure_openai_account_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  kind                = "OpenAI"
  sku_name            = "S0"

  custom_subdomain_name = local.azure_openai_custom_subdomain

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = local.azure_openai_chat_deployment
  cognitive_account_id = azurerm_cognitive_account.openai.id

  sku {
    name     = "GlobalStandard"
    capacity = 1
  }

  model {
    format  = "OpenAI"
    name    = local.azure_openai_chat_model
    version = local.azure_openai_chat_model_version
  }
}

resource "azurerm_cognitive_deployment" "embed" {
  name                 = local.azure_openai_embed_deployment
  cognitive_account_id = azurerm_cognitive_account.openai.id

  sku {
    name     = "Standard"
    capacity = 20
  }

  model {
    format  = "OpenAI"
    name    = local.azure_openai_embed_model
    version = local.azure_openai_embed_model_version
  }
}

resource "azurerm_key_vault_secret" "azure_openai_api_key" {
  name         = "azure-openai-api-key"
  value        = azurerm_cognitive_account.openai.primary_access_key
  key_vault_id = data.azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "azure_openai_endpoint" {
  name         = "azure-openai-endpoint"
  value        = azurerm_cognitive_account.openai.endpoint
  key_vault_id = data.azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "azure_openai_chat_deployment" {
  name         = "azure-openai-chat-deployment"
  value        = azurerm_cognitive_deployment.chat.name
  key_vault_id = data.azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "azure_openai_embed_deployment" {
  name         = "azure-openai-embed-deployment"
  value        = azurerm_cognitive_deployment.embed.name
  key_vault_id = data.azurerm_key_vault.this.id
}
