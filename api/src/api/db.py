from __future__ import annotations

from dataclasses import dataclass

import psycopg
from pgvector.psycopg import register_vector

from . import config


@dataclass(frozen=True)
class EvidenceRow:
    page_title: str
    section_title: str
    url: str
    revision_id: int | None
    text: str
    distance: float | None


def connect() -> psycopg.Connection:
    conn = psycopg.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        dbname=config.DB_NAME,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        connect_timeout=10,
        sslmode="require",
    )
    register_vector(conn)
    return conn


def fetch_evidence(
    conn: psycopg.Connection,
    query_embedding: list[float],
    k: int,
) -> list[EvidenceRow]:
    table_name = f"{config.VEC_SCHEMA}.data_{config.VEC_TABLE}"

    sql = f"""
      SELECT
        COALESCE(metadata_->>'page_title', '') AS page_title,
        COALESCE(metadata_->>'section_title', '') AS section_title,
        COALESCE(metadata_->>'url', '') AS url,
        NULLIF(metadata_->>'revision_id', '')::bigint AS revision_id,
        text,
        (embedding <-> %s) AS distance
      FROM {table_name}
      ORDER BY embedding <-> %s
      LIMIT %s
    """

    with conn.cursor() as cur:
        cur.execute(sql, (query_embedding, query_embedding, k))
        rows = cur.fetchall()

    return [
        EvidenceRow(
            page_title=r[0],
            section_title=r[1],
            url=r[2],
            revision_id=int(r[3]) if r[3] is not None else None,
            text=r[4] or "",
            distance=float(r[5]) if r[5] is not None else None,
        )
        for r in rows
    ]
