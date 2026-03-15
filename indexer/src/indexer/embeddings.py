from llama_index.core import Settings
from llama_index.embeddings.openai import OpenAIEmbedding

from . import settings


def configure_embeddings() -> None:
    Settings.embed_model = OpenAIEmbedding(
        model=settings.EMBED_MODEL,
        api_key=settings.AZURE_OPENAI_API_KEY,
        api_base=f"{settings.AZURE_OPENAI_ENDPOINT.rstrip('/')}/openai/v1/",
        embed_batch_size=100,
    )
