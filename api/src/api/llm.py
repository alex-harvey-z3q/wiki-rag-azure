from __future__ import annotations

from openai import OpenAI

from . import config


def _client() -> OpenAI:
    return OpenAI(
        api_key=config.AZURE_OPENAI_API_KEY,
        base_url=f"{config.AZURE_OPENAI_ENDPOINT.rstrip('/')}/openai/v1/",
    )


def embed_text(text: str) -> list[float]:
    client = _client()
    resp = client.embeddings.create(
        model=config.AZURE_OPENAI_EMBED_DEPLOYMENT,
        input=text,
    )
    return list(resp.data[0].embedding)


def answer_with_evidence(question: str, evidence_items: list[dict]) -> str:
    client = _client()

    system = (
        "You are a careful assistant answering questions using ONLY the provided evidence excerpts from Wikipedia. "
        "If the evidence is insufficient, say you don't know and suggest what page or section would be needed. "
        "Always include citations like [1], [2] corresponding to the evidence list."
    )

    evidence_block = "\n\n".join(
        f"[{i+1}] {e['page']} — {e['section']}\n"
        f"URL: {e['url']}\n"
        f"Excerpt: {e['excerpt']}"
        for i, e in enumerate(evidence_items)
    )

    user = f"Question: {question}\n\nEvidence:\n{evidence_block}"

    resp = client.responses.create(
        model=config.AZURE_OPENAI_CHAT_DEPLOYMENT,
        input=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.2,
    )

    return getattr(resp, "output_text", "") or ""
