# Statement parser service (optional)

The Flutter app parses selectable-text BPI PDFs **on the device**. This
FastAPI service is the same pipeline for CI, a future OCR fallback, or a
locked-down server that never keeps the file.

It does **not** need a paid AI API. It never logs full account numbers.

## Run locally

```powershell
cd parser
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
$env:SUPABASE_JWT_SECRET = "<Project Settings → API → JWT Secret>"
uvicorn app.main:app --host 127.0.0.1 --port 8787
```

`POST /parse` with `Authorization: Bearer <user access token>` and
`multipart/form-data` field `file`.

OCR is off unless `STATEMENT_OCR=1` and Tesseract is installed.

Do not deploy this with the Supabase **service-role** key. Verify the user
JWT only.
