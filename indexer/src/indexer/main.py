import os
import sys
import traceback

from llama_index.core import VectorStoreIndex

from indexer.loader import load_documents
from indexer.nodes import get_splitter
from indexer.embeddings import configure_embeddings
from indexer.vectorstore import get_storage_context


def log(msg: str) -> None:
    print(msg, flush=True)


def main() -> None:
    log("Indexer starting")

    embed_batch_size = int(os.getenv("EMBED_BATCH_SIZE", "20"))
    log(f"Embedding batch size env is {embed_batch_size}")

    log("Configuring embeddings...")
    configure_embeddings()

    log("Loading documents...")
    docs = load_documents()
    log(f"Loaded {len(docs)} documents")

    log("Creating splitter...")
    splitter = get_splitter()

    log("Creating storage context...")
    storage_context = get_storage_context()

    log("Building index...")
    VectorStoreIndex.from_documents(
        docs,
        transformations=[splitter],
        storage_context=storage_context,
        show_progress=False,
    )

    log(f"Indexed {len(docs)} documents into Postgres pgvector")
    log("Indexer completed successfully")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log("Indexer failed with exception:")
        traceback.print_exc()
        sys.exit(1)
