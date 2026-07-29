# Install — QXAudit

Flow: **Chat Input → QXAudit host → docs_ask → RAG helper → Chat Output**

1. `cp .env.example .env` and set `OPENAI_API_KEY`, `APP_NAME=QXAudit`, `LLM_MODEL=gpt-4.1`
2. Put documents into `data/docs/`
3. `pip install -r requirements.txt` **or** `docker compose build && docker compose up -d`
4. Start embedding-service if using `RAG_EMBED_PROVIDER=remote`
5. `curl http://127.0.0.1:9090/ready` (Docker host port; override with `HOST_PORT`)
6. `POST /v1/docs/reindex` then `POST /v1/chat` or `POST /v1/docs/chat`

Prompt files:

- `prompts/hermes_coordinator.md` — QXAudit host
- `prompts/rag_agent_system.md` — RAG helper
