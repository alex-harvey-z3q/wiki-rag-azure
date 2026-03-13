#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

readonly DEFAULT_INDEXER_JOB_NAME="wiki-rag-azure-indexer"
readonly DEFAULT_POSTGRES_ADMIN_USERNAME="wikirdb"
readonly DEFAULT_PGVECTOR_SCHEMA="public"
readonly DEFAULT_PGVECTOR_TABLE="wiki_rag_nodes"
readonly DEFAULT_AZURE_LOCATION="australiaeast"
readonly DEFAULT_CPU="0.5"
readonly DEFAULT_MEMORY="1.0Gi"
readonly DEFAULT_REPLICA_TIMEOUT="3600"
readonly DEFAULT_PARALLELISM="1"
readonly DEFAULT_COMPLETIONS="1"
readonly DEFAULT_INDEXER_CRON="0 */12 * * *"
readonly DEFAULT_PARSED_CONTAINER="parsed"
readonly DEFAULT_PARSED_PREFIX="docs/"
readonly INDEXER_IMAGE_NAME="wiki-rag-indexer"
readonly INDEXER_DOCKERFILE="indexer/Dockerfile"
readonly INDEXER_BUILD_CONTEXT="indexer"

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
  require_env STORAGE_ACCOUNT_NAME
}

init_vars() {
  indexer_job_name="${INDEXER_JOB_NAME:-$DEFAULT_INDEXER_JOB_NAME}"
  postgres_admin_username="${POSTGRES_ADMIN_USERNAME:-$DEFAULT_POSTGRES_ADMIN_USERNAME}"
  pgvector_schema="${PGVECTOR_SCHEMA:-$DEFAULT_PGVECTOR_SCHEMA}"
  pgvector_table="${PGVECTOR_TABLE:-$DEFAULT_PGVECTOR_TABLE}"
  azure_location="${AZURE_LOCATION:-$DEFAULT_AZURE_LOCATION}"
  cpu="${CPU:-$DEFAULT_CPU}"
  memory="${MEMORY:-$DEFAULT_MEMORY}"
  replica_timeout="${REPLICA_TIMEOUT:-$DEFAULT_REPLICA_TIMEOUT}"
  parallelism="${PARALLELISM:-$DEFAULT_PARALLELISM}"
  completions="${COMPLETIONS:-$DEFAULT_COMPLETIONS}"
  indexer_cron="${INDEXER_CRON:-$DEFAULT_INDEXER_CRON}"
  parsed_container="${PARSED_CONTAINER:-$DEFAULT_PARSED_CONTAINER}"
  parsed_prefix="${PARSED_PREFIX:-$DEFAULT_PARSED_PREFIX}"

  acr_login_server="$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)"
  acr_username="$(az acr credential show --name "$ACR_NAME" --query username -o tsv)"
  acr_password="$(az acr credential show --name "$ACR_NAME" --query passwords[0].value -o tsv)"
  storage_connection_string="$(az storage account show-connection-string --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --query connectionString -o tsv)"
  image_uri="$acr_login_server"/"$INDEXER_IMAGE_NAME":"$GITHUB_SHA"
  latest_uri="$acr_login_server"/"$INDEXER_IMAGE_NAME":latest
}

build_and_push() {
  log "Logging in to ACR ${ACR_NAME}"
  az acr login --name "$ACR_NAME" >/dev/null

  log "Building ${image_uri}"
  docker build -f "$INDEXER_DOCKERFILE" -t "$image_uri" "$INDEXER_BUILD_CONTEXT"
  docker push "$image_uri"
  docker tag "$image_uri" "$latest_uri"
  docker push "$latest_uri"
}

_build_secret_array() {
  local db_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/db-password
  local api_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/azure-openai-api-key
  local endpoint_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/azure-openai-endpoint
  local embed_secret_url=https://"$KEY_VAULT_NAME".vault.azure.net/secrets/azure-openai-embed-deployment

  # shellcheck disable=SC2054
  secrets=(
    db-password=keyvaultref:"$db_secret_url",identityref:"$KV_READER_IDENTITY_ID"
    azure-openai-api-key=keyvaultref:"$api_secret_url",identityref:"$KV_READER_IDENTITY_ID"
    azure-openai-endpoint=keyvaultref:"$endpoint_secret_url",identityref:"$KV_READER_IDENTITY_ID"
    azure-openai-embed-deployment=keyvaultref:"$embed_secret_url",identityref:"$KV_READER_IDENTITY_ID"
    storage-connection-string="$storage_connection_string"
  )
}

_build_env_array() {
  env_vars=(
    PARSED_CONTAINER="$parsed_container"
    PARSED_PREFIX="$parsed_prefix"
    AZURE_STORAGE_CONNECTION_STRING=secretref:storage-connection-string
    DB_HOST="$POSTGRES_FQDN"
    DB_PORT=5432
    DB_NAME=postgres
    DB_USER="$postgres_admin_username"
    DB_PASSWORD=secretref:db-password
    AZURE_OPENAI_ENDPOINT=secretref:azure-openai-endpoint
    AZURE_OPENAI_API_KEY=secretref:azure-openai-api-key
    AZURE_OPENAI_EMBED_DEPLOYMENT=secretref:azure-openai-embed-deployment
    PGVECTOR_SCHEMA="$pgvector_schema"
    PGVECTOR_TABLE="$pgvector_table"
  )
}

_update() {
  log "Updating existing Container Apps job $indexer_job_name"

  _build_secret_array
  _build_env_array

  az containerapp job secret set \
    --name "$indexer_job_name" \
    --resource-group "$RESOURCE_GROUP" \
    --secrets "${secrets[@]}" >/dev/null

  az containerapp job update \
    --name           "$indexer_job_name" \
    --resource-group "$RESOURCE_GROUP" \
    --image          "$image_uri" \
    --cpu            "$cpu" \
    --memory         "$memory" \
    --set-env-vars   "${env_vars[@]}"    >/dev/null
}

_create() {
  log "Creating Container Apps job $indexer_job_name"

  _build_secret_array
  _build_env_array

  az containerapp job create \
    --name                     "$indexer_job_name" \
    --resource-group           "$RESOURCE_GROUP" \
    --environment              "$CONTAINERAPPS_ENVIRONMENT" \
    --location                 "$azure_location" \
    --user-assigned            "$KV_READER_IDENTITY_ID" \
    --trigger-type             Schedule \
    --cron-expression          "$indexer_cron" \
    --replica-timeout          "$replica_timeout" \
    --replica-retry-limit      1 \
    --parallelism              "$parallelism" \
    --replica-completion-count "$completions" \
    --image                    "$image_uri" \
    --registry-server          "$acr_login_server" \
    --registry-user            "$acr_username" \
    --registry-pass            "$acr_password" \
    --cpu                      "$cpu" \
    --memory                   "$memory" \
    --secrets                  "${secrets[@]}" \
    --env-vars                 "${env_vars[@]}"     >/dev/null
}

create_or_update() {
  if az containerapp job show \
    --name "$indexer_job_name" \
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
