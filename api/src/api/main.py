from __future__ import annotations

import logging

from fastapi import FastAPI, HTTPException

from . import config
from .llm import answer_with_evidence
from .models import AskRequest, AskResponse, EvidenceItem
from .retrieval import retrieve

logger = logging.getLogger("wiki_rag_api")
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="wiki-rag API")


@app.get("/health")
def health() -> dict:
    return {"ok": True}


def _coerce_int(v) -> int | None:
    if v is None:
        return None
    if isinstance(v, int):
        return v
    try:
        return int(v)
    except Exception:
        return None


@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest) -> AskResponse:
    question = req.question.strip()
    if not question:
        raise HTTPException(status_code=400, detail="question is required")

    try:
        source_rows = retrieve(question)
    except Exception as e:
        logger.exception("Retrieval failed")
        raise HTTPException(status_code=500, detail=f"retrieval failed: {e}")

    if not source_rows:
        raise HTTPException(status_code=404, detail="no evidence found")

    evidence: list[EvidenceItem] = []
    evidence_payload: list[dict] = []

    for row in source_rows:
        excerpt = (row.text or "").strip()
        if len(excerpt) > config.MAX_EVIDENCE_CHARS:
            excerpt = excerpt[: config.MAX_EVIDENCE_CHARS].rstrip() + "…"

        item = EvidenceItem(
            page=row.page_title,
            section=row.section_title,
            url=row.url,
            revision_id=_coerce_int(row.revision_id),
            excerpt=excerpt,
        )
        evidence.append(item)
        evidence_payload.append(item.model_dump())

    try:
        answer = answer_with_evidence(question, evidence_payload)
    except Exception as e:
        logger.exception("LLM answer failed")
        raise HTTPException(status_code=500, detail=f"llm failed: {e}")

    return AskResponse(answer=answer, evidence=evidence)
