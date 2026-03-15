from urllib.parse import quote_plus

from llama_index.vector_stores.postgres import PGVectorStore
from llama_index.core import StorageContext

from indexer.settings import (
    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SSLMODE,
    PGVECTOR_TABLE, PGVECTOR_SCHEMA
)

EMBED_DIM = 3072


def get_storage_context():
    user = quote_plus(DB_USER)
    password = quote_plus(DB_PASSWORD)

    connection_string = (
        f"postgresql+psycopg2://{user}:{password}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
        f"?sslmode={DB_SSLMODE}"
    )

    async_connection_string = (
        f"postgresql+asyncpg://{user}:{password}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
        f"?ssl={DB_SSLMODE}"
    )

    vector_store = PGVectorStore.from_params(
        connection_string=connection_string,
        async_connection_string=async_connection_string,
        table_name=PGVECTOR_TABLE,
        schema_name=PGVECTOR_SCHEMA,
        embed_dim=EMBED_DIM,
    )

    return StorageContext.from_defaults(vector_store=vector_store)
