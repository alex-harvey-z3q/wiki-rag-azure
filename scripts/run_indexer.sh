#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

readonly DEFAULT_RESOURCE_GROUP="wiki-rag-azure-rg"
readonly DEFAULT_INDEXER_JOB_NAME="wiki-rag-azure-indexer"

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
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

init_vars() {
  resource_group="${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}"
  indexer_job_name="${INDEXER_JOB_NAME:-$DEFAULT_INDEXER_JOB_NAME}"
}

ensure_job_exists() {
  az containerapp job show \
    --name "$indexer_job_name" \
    --resource-group "$resource_group" \
    >/dev/null 2>&1 \
    || die "Container Apps job not found: ${indexer_job_name} in resource group ${resource_group}"
}

start_job() {
  az containerapp job start \
    --name "$indexer_job_name" \
    --resource-group "$resource_group" \
    --query name \
    --output tsv
}

get_latest_execution_name() {
  az containerapp job execution list \
    --name "$indexer_job_name" \
    --resource-group "$resource_group" \
    --query "sort_by([], &properties.startTime)[-1].name" \
    --output tsv
}

get_execution_status() {
  local execution_name="$1"

  az containerapp job execution show \
    --name "$indexer_job_name" \
    --resource-group "$resource_group" \
    --job-execution-name "$execution_name" \
    --query "properties.status" \
    --output tsv
}

wait_for_execution_terminal_state() {
  local execution_name="$1"
  local state=""

  while true; do
    state="$(get_execution_status "$execution_name")"
    [[ -n "$state" && "$state" != "None" ]] \
      || die "Could not determine execution status for $execution_name"

    log "Execution status: $state"

    case "$state" in
      Succeeded)
        return 0
        ;;
      Failed|Canceled|Cancelled)
        die "Indexer execution ended with status $state"
        ;;
      *)
        sleep 10
        ;;
    esac
  done
}

show_execution_summary() {
  local execution_name="$1"

  az containerapp job execution show \
    --name "$indexer_job_name" \
    --resource-group "$resource_group" \
    --job-execution-name "$execution_name" \
    --output table
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  require_cmd az
  init_vars

  log "Checking that indexer job exists..."
  ensure_job_exists

  log "Starting indexer job $indexer_job_name..."
  start_job >/dev/null

  log "Resolving latest execution..."
  sleep 5

  local execution_name
  execution_name="$(get_latest_execution_name)"
  [[ -n "$execution_name" && "$execution_name" != "None" ]] \
    || die "Could not resolve execution name for job $indexer_job_name"

  log "Execution name: $execution_name"
  log "Waiting for execution to finish..."

  wait_for_execution_terminal_state "$execution_name"

  log "Execution summary:"
  show_execution_summary "$execution_name"

  log "Indexer completed successfully."
}

main "$@"
