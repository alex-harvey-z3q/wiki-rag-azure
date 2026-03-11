from __future__ import annotations

from functools import lru_cache

from llama_index.core import VectorStoreIndex
from llama_index.embeddings.openai import OpenAIEmbedding
from llama_index.vector_stores.postgres import PGVectorStore

from . import config


@lru_cache(maxsize=1)
def _get_retriever():
    embed_model = OpenAIEmbedding(
        model=config.AZURE_OPENAI_EMBED_DEPLOYMENT,
        api_key=config.AZURE_OPENAI_API_KEY,
        api_base=f"{config.AZURE_OPENAI_ENDPOINT.rstrip('/')}/openai/v1/",
    )

    vector_store = PGVectorStore.from_params(
        host=config.DB_HOST,
        port=config.DB_PORT,
        database=config.DB_NAME,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        table_name=config.VEC_TABLE,
        schema_name=config.VEC_SCHEMA,
        embed_dim=config.EMBED_DIM,
    )

    index = VectorStoreIndex.from_vector_store(vector_store=vector_store, embed_model=embed_model)
    return index.as_retriever(similarity_top_k=config.TOP_K)


def retrieve(question: str):
    return _get_retriever().retrieve(question)
