# wiki-rag-azure

Azure rewrite of the original wiki-rag pipeline.

This version keeps the same three-stage architecture:
1. ingest Wikipedia content into Azure Blob Storage
2. index documents into Azure Database for PostgreSQL with pgvector
3. serve a FastAPI RAG API from Azure Container Apps

## Azure service mapping

- **S3** -> **Azure Blob Storage**
- **RDS PostgreSQL** -> **Azure Database for PostgreSQL Flexible Server**
- **ECS Fargate service** -> **Azure Container Apps**
- **EventBridge scheduled tasks** -> **Azure Container Apps Jobs**
- **ECR** -> **Azure Container Registry**
- **Secrets Manager** -> **Azure Key Vault**
- **CloudWatch Logs** -> **Azure Log Analytics**
- **GitHub OIDC to AWS IAM** -> **GitHub OIDC to Azure federated identity**

## Prereqs

- Terraform >= 1.6
- Azure CLI logged into the target subscription
- Docker
- A GitHub repository with Actions enabled
- An Azure OpenAI resource with chat and embedding deployments

## Required secrets

Store these in Key Vault, or inject them as Container App secrets during development:

- `db-password`
- `azure-openai-api-key`
- `azure-openai-endpoint`
- `azure-openai-chat-deployment`
- `azure-openai-embed-deployment`
- `storage-connection-string` (optional for local runs; managed identity is preferred in Azure)

## Setup

1. Set up the Azure CLI.
2. Login to personal account.
3. Register required providers:

```bash
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.DBforPostgreSQL
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
```

4. Configure Terraform auth

```bash
az account show
```

5. Create the RG:

```bash
az group create --name wiki-rag-rg --location australiaeast
```

6. Create a Key Vault:

```bash
kv_name=wiki-rag-kv-ah
rg=wiki-rag-rg
loc=australiaeast

az keyvault create \
  --name "$kv_name" \
  --resource-group "$rg" \
  --location "$loc" \
  --enable-rbac-authorization true
```

7. Set the secrets

```bash
manage-kv-secret.sh -v "$kv_name" -c db-password -s 'xxx'
manage-kv-secret.sh -v "$kv_name" -c azure-openai-api-key -s 'xxx'
```

8. Check

```bash
% az keyvault secret list --vault-name "$kv_name" -o table
Name                  Id                                                                   ContentType    Enabled    Expires
--------------------  -------------------------------------------------------------------  -------------  ---------  ---------
azure-openai-api-key  https://wiki-rag-kv-ah.vault.azure.net/secrets/azure-openai-api-key                 True
db-password           https://wiki-rag-kv-ah.vault.azure.net/secrets/db-password                          True
```

## Deploy infrastructure

```bash
cd infra
terraform init
terraform apply
```

## Deploy containers

The included GitHub Actions workflows build images in Azure Container Registry and update the Container Apps resources.

- `deploy-api`
- `deploy-ingest`
- `deploy-indexer`

## First run

Run the ingest job once, then the indexer job once.

```bash
az containerapp job start --name wiki-rag-ingest --resource-group wiki-rag-rg
az containerapp job start --name wiki-rag-indexer --resource-group wiki-rag-rg
```

## Test the API

```bash
API_URL=$(terraform -chdir=infra output -raw api_url)
curl -sS -X POST "$API_URL/ask"   -H "Content-Type: application/json"   -d '{"question":"What documents were indexed?"}'
```

## Notes

This rewrite is designed to be close to the original codebase so the cloud-specific changes are easy to follow. It has not been validated against a live Azure subscription in this environment, so treat it as a strong starting point rather than a guaranteed drop-in deployment.
