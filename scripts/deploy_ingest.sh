#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

readonly DEFAULT_INGEST_JOB_NAME="wiki-rag-azure-ingest"
readonly DEFAULT_AZURE_LOCATION="australiaeast"
readonly DEFAULT_CPU="0.5"
readonly DEFAULT_MEMORY="1.0Gi"
readonly DEFAULT_REPLICA_TIMEOUT="1800"
readonly DEFAULT_PARALLELISM="1"
readonly DEFAULT_COMPLETIONS="1"
readonly DEFAULT_INGEST_CRON="0 */6 * * *"
readonly DEFAULT_RAW_CONTAINER="raw"
readonly DEFAULT_PARSED_CONTAINER="parsed"
readonly INGEST_IMAGE_NAME="wiki-rag-ingest"
readonly INGEST_DOCKERFILE="ingest/Dockerfile"
readonly INGEST_BUILD_CONTEXT="ingest"

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
  require_env STORAGE_ACCOUNT_NAME
}

init_vars() {
  ingest_job_name="${INGEST_JOB_NAME:-$DEFAULT_INGEST_JOB_NAME}"
  azure_location="${AZURE_LOCATION:-$DEFAULT_AZURE_LOCATION}"
  cpu="${CPU:-$DEFAULT_CPU}"
  memory="${MEMORY:-$DEFAULT_MEMORY}"
  replica_timeout="${REPLICA_TIMEOUT:-$DEFAULT_REPLICA_TIMEOUT}"
  parallelism="${PARALLELISM:-$DEFAULT_PARALLELISM}"
  completions="${COMPLETIONS:-$DEFAULT_COMPLETIONS}"
  ingest_cron="${INGEST_CRON:-$DEFAULT_INGEST_CRON}"
  raw_container="${RAW_CONTAINER:-$DEFAULT_RAW_CONTAINER}"
  parsed_container="${PARSED_CONTAINER:-$DEFAULT_PARSED_CONTAINER}"

  acr_login_server="$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)"
  acr_username="$(az acr credential show --name "$ACR_NAME" --query username -o tsv)"
  acr_password="$(az acr credential show --name "$ACR_NAME" --query passwords[0].value -o tsv)"
  storage_connection_string="$(az storage account show-connection-string --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --query connectionString -o tsv)"
  image_uri="$acr_login_server"/"$INGEST_IMAGE_NAME":"$GITHUB_SHA"
  latest_uri="$acr_login_server"/"$INGEST_IMAGE_NAME":latest
}

build_and_push() {
  log "Logging in to ACR ${ACR_NAME}"
  az acr login --name "$ACR_NAME" >/dev/null

  log "Building ${image_uri}"
  docker build -f "$INGEST_DOCKERFILE" -t "$image_uri" "$INGEST_BUILD_CONTEXT"
  docker push "$image_uri"
  docker tag "$image_uri" "$latest_uri"
  docker push "$latest_uri"
}

_build_secret_array() {
  secrets=(
    storage-connection-string="$storage_connection_string"
  )
}

_build_env_array() {
  env_vars=(
    RAW_CONTAINER="$raw_container"
    PARSED_CONTAINER="$parsed_container"
    AZURE_STORAGE_CONNECTION_STRING=secretref:storage-connection-string
  )
}

_update() {
  log "Updating existing Container Apps job $ingest_job_name"

  _build_secret_array
  _build_env_array

  az containerapp job secret set \
    --name "$ingest_job_name" \
    --resource-group "$RESOURCE_GROUP" \
    --secrets "${secrets[@]}" >/dev/null

  az containerapp job update \
    --name "$ingest_job_name" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$image_uri" \
    --cpu "$cpu" \
    --memory "$memory" \
    --set-env-vars "${env_vars[@]}" >/dev/null
}

_create() {
  log "Creating Container Apps job $ingest_job_name"

  _build_secret_array
  _build_env_array

  az containerapp job create \
    --name            "$ingest_job_name" \
    --resource-group  "$RESOURCE_GROUP" \
    --environment     "$CONTAINERAPPS_ENVIRONMENT" \
    --location        "$azure_location" \
    --trigger-type    Schedule \
    --cron-expression "$ingest_cron" \
    --replica-timeout "$replica_timeout" \
    --replica-retry-limit 1 \
    --parallelism     "$parallelism" \
    --replica-completion-count "$completions" \
    --image           "$image_uri" \
    --registry-server "$acr_login_server" \
    --registry-user   "$acr_username" \
    --registry-pass   "$acr_password" \
    --cpu             "$cpu" \
    --memory          "$memory" \
    --secrets         "${secrets[@]}" \
    --env-vars        "${env_vars[@]}"   >/dev/null
}

create_or_update() {
  if az containerapp job show \
    --name "$ingest_job_name" \
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
