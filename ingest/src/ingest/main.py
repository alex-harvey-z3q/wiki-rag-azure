import os
from datetime import datetime, timezone

from ingest.wikipedia import fetch_page
from ingest.parser import split_sections
from ingest.models import NormalizedDocument
from ingest.blob import put_json

RAW_CONTAINER = os.environ.get("RAW_CONTAINER", "raw")
PARSED_CONTAINER = os.environ.get("PARSED_CONTAINER", "parsed")


PAGES = [
    "Artificial intelligence",
    "Machine learning",
    "Large language model",
]


def process_page(title: str) -> None:
    """Normalise a single Wikipedia page and persist its contents to S3."""

    page = fetch_page(title)
    page_id = page["pageid"]
    content = page["revisions"][0]["slots"]["main"]["*"]
    fetched_at = datetime.now(timezone.utc).isoformat()

    put_json(RAW_CONTAINER, f"pages/{page_id}.json", page)

    for section, text in split_sections(content):
        process_section(page_id, title, section, text, fetched_at)


def process_section(
    page_id: int,
    title: str,
    section: str,
    text: str,
    fetched_at: str,
) -> None:
    """Normalise a single Wikipedia section and persist it to S3."""

    if not text.strip():
        return

    doc = NormalizedDocument(
        doc_id=f"wiki:{page_id}:{section}",
        source="wikipedia",
        page_id=page_id,
        title=title,
        section=section,
        text=text,
        metadata={
            "url": f"https://en.wikipedia.org/wiki/{title.replace(' ', '_')}",
            "fetched_at": fetched_at,
        },
    )

    put_json(
        PARSED_CONTAINER,
        f"docs/{page_id}/{section}.json",
        doc.to_dict(),
    )


def main() -> None:
    for title in PAGES:
        process_page(title)


if __name__ == "__main__":
    main()
