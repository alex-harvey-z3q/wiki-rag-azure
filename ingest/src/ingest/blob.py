from __future__ import annotations

import json
import os
from functools import lru_cache

from azure.storage.blob import BlobServiceClient


def _connection_string() -> str:
    value = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
    if not value:
        raise RuntimeError("AZURE_STORAGE_CONNECTION_STRING is required")
    return value


@lru_cache(maxsize=1)
def _client() -> BlobServiceClient:
    return BlobServiceClient.from_connection_string(_connection_string())


def put_json(container: str, blob_name: str, payload: dict) -> None:
    client = _client().get_blob_client(container=container, blob=blob_name)
    client.upload_blob(
        json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        blob_type="BlockBlob",
        overwrite=True,
    )
