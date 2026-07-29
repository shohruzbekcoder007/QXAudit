# Local install — QXAudit

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# set OPENAI_API_KEY and APP_NAME=QXAudit in .env
python -m app.main
```

Local (no Docker): http://127.0.0.1:8080/docs  
Docker (default): http://127.0.0.1:9090/docs

Main endpoints:

- `POST /v1/chat` — QXAudit host + `docs_ask`
- `POST /v1/docs/chat` — direct RAG helper
- `POST /v1/docs/reindex` — rebuild Chroma index
