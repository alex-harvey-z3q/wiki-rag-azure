#!/usr/bin/env bash
set -euo pipefail
az containerapp job start --name wiki-rag-indexer --resource-group wiki-rag-rg
