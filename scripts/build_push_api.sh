#!/usr/bin/env bash
set -euo pipefail
RG=${RESOURCE_GROUP:-wiki-rag-rg}
ACR=${ACR_NAME:?ACR_NAME is required}
TAG=${GITHUB_SHA:-latest}
az acr build --registry "$ACR" --image wiki-rag-api:$TAG --image wiki-rag-api:latest ./api
az containerapp update --name wiki-rag-api --resource-group "$RG" --image "$ACR.azurecr.io/wiki-rag-api:$TAG"
