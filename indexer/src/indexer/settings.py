import os

AZURE_STORAGE_CONNECTION_STRING = os.environ["AZURE_STORAGE_CONNECTION_STRING"]
PARSED_CONTAINER = os.environ.get("PARSED_CONTAINER", "parsed")
PARSED_PREFIX = os.environ.get("PARSED_PREFIX", "docs/")

AZURE_OPENAI_API_KEY = os.environ["AZURE_OPENAI_API_KEY"]
AZURE_OPENAI_ENDPOINT = os.environ["AZURE_OPENAI_ENDPOINT"]
AZURE_OPENAI_API_VERSION = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-10-21")
EMBED_MODEL = os.environ["AZURE_OPENAI_EMBED_DEPLOYMENT"]

DB_HOST = os.environ["DB_HOST"]
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "postgres")
DB_USER = os.environ["DB_USER"]
DB_PASSWORD = os.environ["DB_PASSWORD"]

PGVECTOR_TABLE = os.environ.get("PGVECTOR_TABLE", "wiki_rag_nodes")
PGVECTOR_SCHEMA = os.environ.get("PGVECTOR_SCHEMA", "public")
