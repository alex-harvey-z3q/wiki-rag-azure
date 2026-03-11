from __future__ import annotations

import os


def _req(name: str) -> str:
    v = os.getenv(name)
    if not v:
        raise RuntimeError(f"Missing required env var: {name}")
    return v


DB_HOST: str = _req("DB_HOST")
DB_PORT: int = int(os.getenv("DB_PORT", "5432"))
DB_NAME: str = os.getenv("DB_NAME", "postgres")
DB_USER: str = _req("DB_USER")
DB_PASSWORD: str = _req("DB_PASSWORD")

AZURE_OPENAI_API_KEY: str = _req("AZURE_OPENAI_API_KEY")
AZURE_OPENAI_ENDPOINT: str = _req("AZURE_OPENAI_ENDPOINT")
AZURE_OPENAI_CHAT_DEPLOYMENT: str = _req("AZURE_OPENAI_CHAT_DEPLOYMENT")
AZURE_OPENAI_EMBED_DEPLOYMENT: str = _req("AZURE_OPENAI_EMBED_DEPLOYMENT")

TOP_K: int = int(os.getenv("TOP_K", "6"))
MAX_EVIDENCE_CHARS: int = int(os.getenv("MAX_EVIDENCE_CHARS", "1200"))
VEC_SCHEMA: str = os.getenv("VEC_SCHEMA", "public")
VEC_TABLE: str = os.getenv("VEC_TABLE", "data_wiki_rag_nodes")
EMBED_DIM: int = int(os.getenv("EMBED_DIM", "1536"))
