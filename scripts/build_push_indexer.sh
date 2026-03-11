#!/usr/bin/env bash
set -euo pipefail
ACR=${ACR_NAME:?ACR_NAME is required}
TAG=${GITHUB_SHA:-latest}
az acr build --registry "$ACR" --image wiki-rag-indexer:$TAG --image wiki-rag-indexer:latest ./indexer
