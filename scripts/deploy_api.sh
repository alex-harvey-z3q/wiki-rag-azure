#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

readonly DEFAULT_API_APP_NAME="wiki-rag-azure-api"
readonly DEFAULT_POSTGRES_ADMIN_USERNAME="wikirdb"
readonly DEFAULT_PGVECTOR_SCHEMA="public"
readonly DEFAULT_PGVECTOR_TABLE="wiki_rag_nodes"
readonly DEFAULT_AZURE_LOCATION="australiaeast"
readonly API_IMAGE_NAME="wiki-rag-api"
readonly API_DOCKERFILE="api/Dockerfile"
readonly API_BUILD_CONTEXT="api"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

log() {
  echo "[INFO] $*" >&2
}

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_env() {
  [[ -n "${!1:-}" ]] || die "Required environment variable not set: $1"
}

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

validate_prereqs() {
  require_cmd az
  require_cmd docker

  require_env GITHUB_SHA
  require_env ACR_NAME
  require_env RESOURCE_GROUP
  require_env CONTAINERAPPS_ENVIRONMENT
  require_env KV_READER_IDENTITY_ID
  require_env KEY_VAULT_NAME
  require_env POSTGRES_FQDN
}

init_vars() {
  api_app_name="${API_APP_NAME:-$DEFAULT_API_APP_NAME}"
  postgres_admin_username="${POSTGRES_ADMIN_USERNAME:-$DEFAULT_POSTGRES_ADMIN_USERNAME}"
  pgvector_schema="${PGVECTOR_SCHEMA:-$DEFAULT_PGVECTOR_SCHEMA}"
  pgvector_table="${PGVECTOR_TABLE:-$DEFAULT_PGVECTOR_TABLE}"
  azure_location="${AZURE_LOCATION:-$DEFAULT_AZURE_LOCATION}"

  acr_login_server="$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)"
  acr_username="$(az acr credential show --name "$ACR_NAME" --query username -o tsv)"
  acr_password="$(az acr credential show --name "$ACR_NAME" --query passwords[0].value -o tsv)"
  image_uri="$acr_login_server"/"$API_IMAGE_NAME":"$GITHUB_SHA"
  latest_uri="$acr_login_server"/"$API_IMAGE_NAME":latest
}

build_and_push() {
  log "Logging in to ACR ${ACR_NAME}"
  az acr login --name "$ACR_NAME" >/dev/null

  log "Building ${image_uri}"
  docker build -f "$API_DOCKERFILE" -t "$image_uri" "$API_BUILD_CONTEXT"
  docker push "$image_uri"
  docker tag "$image_uri" "$latest_uri"
  docker push "$latest_uri"
}

_build_secret_array() {
  local db_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/db-password
  local api_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/azure-openai-api-key
  local endpoint_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/azure-openai-endpoint
  local chat_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/azure-openai-chat-deployment
  local embed_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/azure-openai-embed-deployment

  # shellcheck disable=SC2054
  secrets=(
    db-password=keyvaultref:"$db_secret_url",identityref:"$KV_READER_IDENTITY_ID"
    azure-openai-api-key=keyvaultref:"$api_secret_url",identityref:"$KV_READER_IDENTITY_ID"
    azure-openai-endpoint=keyvaultref:"$endpoint_secret_url",identityref:"$KV_READER_IDENTITY_ID"
    azure-openai-chat-deployment=keyvaultref:"$chat_secret_url",identityref:"$KV_READER_IDENTITY_ID"
    azure-openai-embed-deployment=keyvaultref:"$embed_secret_url",identityref:"$KV_READER_IDENTITY_ID"
  )
}

_build_env_array() {
  env_vars=(
    "DB_HOST=${POSTGRES_FQDN}"
    "DB_PORT=5432"
    "DB_NAME=postgres"
    "DB_USER=${postgres_admin_username}"
    "DB_PASSWORD=secretref:db-password"
    "AZURE_OPENAI_ENDPOINT=secretref:azure-openai-endpoint"
    "AZURE_OPENAI_API_KEY=secretref:azure-openai-api-key"
    "AZURE_OPENAI_CHAT_DEPLOYMENT=secretref:azure-openai-chat-deployment"
    "AZURE_OPENAI_EMBED_DEPLOYMENT=secretref:azure-openai-embed-deployment"
    "VEC_SCHEMA=${pgvector_schema}"
    "VEC_TABLE=${pgvector_table}"
    "EMBED_DIM=1536"
  )
}

_update() {
  log "Updating existing Container App ${api_app_name}"

  _build_secret_array
  _build_env_array

  az containerapp secret set \
    --name "$api_app_name" \
    --resource-group "$RESOURCE_GROUP" \
    --secrets "${secrets[@]}" >/dev/null

  az containerapp update \
    --name "$api_app_name" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$image_uri" \
    --set-env-vars "${env_vars[@]}" >/dev/null
}

_create() {
  log "Creating Container App ${api_app_name}"

  _build_secret_array
  _build_env_array

  az containerapp create \
    --name "$api_app_name" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$CONTAINERAPPS_ENVIRONMENT" \
    --location "$azure_location" \
    --user-assigned "$KV_READER_IDENTITY_ID" \
    --image "$image_uri" \
    --registry-server "$acr_login_server" \
    --registry-user "$acr_username" \
    --registry-pass "$acr_password" \
    --cpu 0.5 \
    --memory 1.0Gi \
    --target-port 8000 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 1 \
    --secrets "${secrets[@]}" \
    --env-vars "${env_vars[@]}" >/dev/null
}

create_or_update() {
  if az containerapp show \
    --name "$api_app_name" \
    --resource-group "$RESOURCE_GROUP" \
    >/dev/null 2>&1; then
    _update
  else
    _create
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  validate_prereqs
  init_vars
  build_and_push
  create_or_update
}

main "$@"
