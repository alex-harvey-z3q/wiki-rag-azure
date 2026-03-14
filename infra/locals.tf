locals {
  project     = "wiki-rag-azure"
  location    = "australiaeast"
  db_username = "wikirdb"

  github_repo = "alex-harvey-z3q/wiki-rag-azure"

  key_vault_name    = "wiki-rag-kv-ah"
  key_vault_rg_name = "wiki-rag-rg"

  azure_openai_account_name      = "wikiragopenai${random_string.openai_suffix.result}"
  azure_openai_custom_subdomain  = "wikiragopenai${random_string.openai_suffix.result}"

  azure_openai_chat_deployment    = "gpt-4o-mini"
  azure_openai_chat_model         = "gpt-4o-mini"
  azure_openai_chat_model_version = "2024-07-18"

  azure_openai_embed_deployment    = "text-embedding-3-large"
  azure_openai_embed_model         = "text-embedding-3-large"
  azure_openai_embed_model_version = "1"
}
