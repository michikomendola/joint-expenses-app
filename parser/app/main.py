"""Authenticated PDF parse endpoint. Files are held in memory only."""

from __future__ import annotations

import os

import jwt
from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .bpi import parse_bpi_text

app = FastAPI(title="Joint Expenses statement parser", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST"],
    allow_headers=["Authorization", "Content-Type"],
)


def _require_user(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Sign in required.")
    token = authorization.split(" ", 1)[1]
    secret = os.environ.get("SUPABASE_JWT_SECRET", "")
    if not secret:
        raise HTTPException(status_code=500, detail="Parser is not configured.")
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"], audience="authenticated")
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail="Invalid session.") from exc
    subject = payload.get("sub")
    if not subject:
        raise HTTPException(status_code=401, detail="Invalid session.")
    return str(subject)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/parse")
async def parse_statement(
    file: UploadFile = File(...),
    authorization: str | None = Header(default=None),
) -> dict:
    _require_user(authorization)
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Upload a PDF statement.")
    data = await file.read()
    if len(data) > 12 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="The PDF is too large.")
    try:
        import fitz
    except ImportError as exc:
        raise HTTPException(status_code=500, detail="PyMuPDF is not installed.") from exc
    try:
        doc = fitz.open(stream=data, filetype="pdf")
    except Exception as exc:  # noqa: BLE001 — surface as a client error
        raise HTTPException(status_code=400, detail="This file is not a readable PDF.") from exc
    if doc.is_encrypted:
        raise HTTPException(status_code=400, detail="Password-protected PDFs are not supported.")
    pages: list[str] = []
    for page in doc:
        pages.append(page.get_text("text"))
    doc.close()
    text = "\n".join(pages)
    if not text.strip():
        raise HTTPException(
            status_code=422,
            detail="This looks like a scanned statement. OCR is not enabled on this server.",
        )
    return parse_bpi_text(text)
