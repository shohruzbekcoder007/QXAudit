# QXAudit

Asosiy agent: **QXAudit**. Yordamchi agentlar (hozircha RAG) host orqali chaqiriladi.

```text
Open WebUI → Gateway → POST /v1/chat
     → QXAudit host  (conversation + memory)
          → tool: docs_ask
               → RAG helper → Chroma (PDF / Word / FAQ)

Direct RAG (no host): POST /v1/docs/chat
```

## Why this design

- **QXAudit** owns multi-turn context / session history as the main agent.
- **RAG helper** answers from indexed policies/PDF/Word via `docs_ask` and `/v1/docs/*`.
- More helper agents can be added under the same QXAudit host later.
- Gateway: `HERMES_GIS_BASE_URL=http://host.docker.internal:8080` (or your QXAudit base URL).

If the `hermes-agent` package is missing, **hermes_lite** runs the same pattern
(outer tool-calling host + `docs_ask`).

## Configure

```env
APP_NAME=QXAudit
OPENAI_API_KEY=...
LLM_MODEL=gpt-4.1
HERMES_SKIP_MEMORY=false
HERMES_ENABLED_TOOLSETS=docs_bridge

# Document RAG helper + embeddings
RAG_ENABLED=true
RAG_DOCS_DIR=./data/docs
RAG_CHROMA_ROOT=./data/rag/chroma

# Preferred: remote embedding-service (sibling d:\GROK\embedding-service)
RAG_EMBED_PROVIDER=remote
RAG_EMBED_URL=http://host.docker.internal:8090
# RAG_EMBED_BEARER_TOKEN=

# In-process fallback (no separate service):
# RAG_EMBED_PROVIDER=openai
# RAG_EMBED_MODEL=text-embedding-3-small
# Local bge-m3: RAG_EMBED_PROVIDER=local + requirements-rag-local.txt
```

## API

| Method | Path | Role |
|--------|------|------|
| POST | `/v1/chat` | QXAudit host chat (`session_id` for memory) |
| GET | `/ready` | QXAudit host + RAG ready |
| GET | `/v1/info` | Architecture metadata (+ helpers) |
| POST | `/v1/docs/chat` | Document RAG Q&A |
| POST | `/v1/docs/reindex` | Rebuild Chroma for current embed identity |
| GET | `/v1/docs/ready` | RAG ready |
| GET | `/v1/docs/info` | RAG config + stats |
| GET | `/v1/docs/files` | Files under `RAG_DOCS_DIR` |

## Document RAG + Document Intelligence

1. Put PDF / DOCX / MD / TXT into `data/docs/` (Docker volume `./data`).
2. `POST /v1/docs/reindex` (same bearer as chat if `API_BEARER_TOKEN` set).
3. Ask via `POST /v1/docs/chat` or host chat (`docs_ask`).

On reindex the app:

- detects structure (bob/modda / chapter/article) when present;
- stores **document profiles** (counts, type) + TOC chunks;
- indexes article-level chunks with rich metadata (`article_num`, `chapter_num`, `heading_path`);
- falls back to semantic chunks for unstructured files.

Query routing:

| Savol | Mode |
|--------|------|
| Nechta bob/modda? | `structured_counts` (profile stats) |
| 15-modda qaysi bobda? | `hierarchy` + metadata |
| oddiy mazmun | hybrid semantic (embedding-service) |

**Embedding switch:** change model on **embedding-service** env (or local `RAG_EMBED_*`), then **full reindex** here (`POST /v1/docs/reindex`).  
`index_key` comes from the embed service (`provider__model__d{dim}`); Chroma paths never mix dimensions.

```bash
# Terminal 1 — embedding service
cd ../embedding-service && python -m app.main

# Terminal 2 — this app (after RAG_EMBED_PROVIDER=remote)
curl -X POST http://127.0.0.1:9090/v1/docs/reindex
```

## Run

```bash
docker compose build
docker compose up -d
```

By default the app is published on **host port 9090** → container `8080`  
(`HOST_PORT=9090` in `.env`; change if needed).

```bash
curl http://127.0.0.1:9090/health
```

Container / image: `qxaudit`. Network: `qxaudit-net`. Volume: `qxaudit-rag-chroma`.

## Layout

```text
agents/
  hermes_host.py      # QXAudit host (Hermes or hermes_lite)
  embeddings.py       # get_embeddings() from env only
  rag_agent.py        # RAG helper: PDF/Word → Chroma → answer
  rag_bridge_tool.py  # docs_ask tool
  doc_structure.py    # document structure helpers
prompts/
  hermes_coordinator.md   # QXAudit host system prompt
  rag_agent_system.md     # RAG helper prompt
data/
  docs/               # drop PDF/DOCX/MD/TXT here
  rag/chroma/         # per-model Chroma indexes
```
