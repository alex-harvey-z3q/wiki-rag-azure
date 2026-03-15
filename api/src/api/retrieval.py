from __future__ import annotations

from . import config
from .db import connect, fetch_evidence
from .llm import embed_text


def retrieve(question: str):
    query_embedding = embed_text(question)
    with connect() as conn:
        return fetch_evidence(conn, query_embedding, config.TOP_K)
