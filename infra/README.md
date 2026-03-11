# Azure infrastructure

This Terraform stack provisions:

- Resource group
- Log Analytics workspace
- Container Apps environment
- Azure Container Registry
- Blob Storage account and two private containers
- PostgreSQL Flexible Server
- Key Vault
- One Container App for the API
- Two Container Apps Jobs for ingest and indexing

## Important follow-up steps

1. Create the `vector` extension in PostgreSQL if it is not already available.
2. Build and push initial images to ACR.
3. Configure GitHub OIDC or a service principal for GitHub Actions.
4. Consider VNet integration and private endpoints before production use.
