from __future__ import annotations

import json
from io import BytesIO

from azure.storage.blob import BlobServiceClient
from llama_index.core import Document

from . import settings


def load_documents() -> list[Document]:
    service = BlobServiceClient.from_connection_string(settings.AZURE_STORAGE_CONNECTION_STRING)
    container = service.get_container_client(settings.PARSED_CONTAINER)

    docs: list[Document] = []
    for blob in container.list_blobs(name_starts_with=settings.PARSED_PREFIX):
        data = container.download_blob(blob.name).readall()
        payload = json.loads(data)
        metadata = dict(payload.get("metadata") or {})
        metadata.update(
            {
                "doc_id": payload.get("doc_id", ""),
                "page_title": payload.get("title", ""),
                "section_title": payload.get("section", ""),
                "url": metadata.get("url", ""),
            }
        )
        docs.append(Document(text=payload.get("text", ""), metadata=metadata))
    return docs
