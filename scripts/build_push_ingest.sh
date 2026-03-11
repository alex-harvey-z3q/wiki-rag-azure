#!/usr/bin/env bash
set -euo pipefail
ACR=${ACR_NAME:?ACR_NAME is required}
TAG=${GITHUB_SHA:-latest}
az acr build --registry "$ACR" --image wiki-rag-ingest:$TAG --image wiki-rag-ingest:latest ./ingest
