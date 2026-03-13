This bundle contains Azure-oriented replacements for the deployment workflows and scripts.

Expected GitHub repository variables:
- ACR_NAME
- AZURE_RESOURCE_GROUP
- CONTAINERAPPS_ENVIRONMENT
- KV_READER_IDENTITY_ID
- KEY_VAULT_NAME
- POSTGRES_FQDN
- POSTGRES_ADMIN_USERNAME
- STORAGE_ACCOUNT_NAME
- RAW_CONTAINER_NAME
- PARSED_CONTAINER_NAME
- API_APP_NAME
- INGEST_JOB_NAME
- INDEXER_JOB_NAME
- PGVECTOR_SCHEMA
- PGVECTOR_TABLE
- AZURE_LOCATION

Expected GitHub repository secrets:
- AZURE_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_SUBSCRIPTION_ID

Defaults baked into scripts if vars are omitted:
- KEY_VAULT_NAME=wiki-rag-kv-ah
- POSTGRES_ADMIN_USERNAME=wikirdb
- RAW_CONTAINER_NAME=raw
- PARSED_CONTAINER_NAME=parsed
- API_APP_NAME=wiki-rag-azure-api
- INGEST_JOB_NAME=wiki-rag-azure-ingest
- INDEXER_JOB_NAME=wiki-rag-azure-indexer
- PGVECTOR_SCHEMA=public
- PGVECTOR_TABLE=wiki_rag_nodes
- AZURE_LOCATION=australiaeast
