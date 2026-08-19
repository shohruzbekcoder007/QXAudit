# QXAudit

Asosiy agent: **QXAudit**. Yordamchi agentlar: **RAG**, **DocViewer** (boshqalar keyin).

```text
Open WebUI → Gateway → POST /v1/chat
     → QXAudit host  (conversation + memory)
          → tool: docs_ask
               → RAG helper → Chroma (PDF / Word / FAQ)

Direct RAG (no host): POST /v1/docs/chat
DocViewer (JSON in):  POST /v1/docviewer/run
Graph (Neo4j templates): POST /v1/graph/ask  ·  host tool graph_ask
Reconcile (deterministic): POST /v1/graph/reconcile  ·  host tool reconcile_check
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
| POST | `/v1/chat/completions` | OpenAI-compatible (Open WebUI Gateway Accounting, etc.) |
| POST | `/v1/graph/ask` | Neo4j template query (`graph_ask`: intent + name/code/number) |
| GET | `/v1/graph/ready` | Neo4j connectivity |
| GET | `/v1/graph/intents` | Allowed graph intents |
| POST | `/v1/graph/reconcile` | Deterministic identity checks (`reconcile_check`) |
| GET | `/v1/graph/checks` | Allowed reconcile checks |
| GET | `/ready` | QXAudit host + RAG ready |
| GET | `/v1/info` | Architecture metadata (+ helpers) |
| POST | `/v1/docs/chat` | Document RAG Q&A |
| POST | `/v1/docs/reindex` | Rebuild Chroma for current embed identity |
| GET | `/v1/docs/ready` | RAG ready |
| GET | `/v1/docs/info` | RAG config + stats |
| GET | `/v1/docs/files` | Files under `RAG_DOCS_DIR` |
| GET | `/v1/self-improve` | Learned Q/A recipe store stats |
| POST | `/v1/docviewer/run` | DocViewer: JSON document + tools |
| GET | `/v1/docviewer/info` | DocViewer agent + tool list |
| GET | `/v1/docviewer/tools` | Registered DocViewer tools |
| GET | `/v1/docviewer/ready` | DocViewer ready |

### Session id (Open WebUI)

- Preferred path: Gateway agent with `api_style: message` + `POST /v1/chat`  
  (Accounting is configured this way so `session_id` / chat id is forwarded).
- OpenAI path `POST /v1/chat/completions` also accepts:
  - body `session_id` / `chat_id`
  - headers `X-OpenWebUI-Chat-Id`, `X-Session-Id`
  - fallback: stable fingerprint of first user message in the thread

### Self-improving

Successful Q→A pairs are stored in `data/self_improve.json` (global).  
Similar past answers are injected as few-shot hints into the host prompt  
(`SELF_IMPROVE_*` env). Inspect: `GET /v1/self-improve`.

### DocViewer (primitive)

JSON document agent under `QXAudit.docviewer`. Tools (stubs for now):

- `metadata_extractor` — Metadata Extractor Tool  
- `knowledge_graph_builder` — Knowledge Graph Builder Tool  

```bash
curl -X POST http://127.0.0.1:9090/v1/docviewer/run \
  -H "Content-Type: application/json" \
  -d "{\"document\":{\"title\":\"demo\",\"pages\":1},\"run_all\":true}"
```

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

### Neo4j (graph store)

Compose service **`neo4j`** (`qxaudit-neo4j`) — persistent volumes for the graph.
Agent/tool wiring comes later; the DB is ready to use now.

| | |
|--|--|
| Browser UI | http://127.0.0.1:7474 |
| Bolt (host) | `bolt://127.0.0.1:7687` |
| Bolt (from app) | `bolt://neo4j:7687` |
| User / password | `NEO4J_USER` / `NEO4J_PASSWORD` in `.env` |

Volumes: `qxaudit-neo4j-data`, `qxaudit-neo4j-logs`, `qxaudit-neo4j-import`, `qxaudit-neo4j-plugins`.

```bash
# Start / check
docker compose up -d neo4j
docker compose ps neo4j
docker compose logs -f neo4j
```

First browser login: user `neo4j`, password from `.env` (`NEO4J_PASSWORD`).  
On first connect Neo4j may ask you to set a new password if auth policy requires it — keep `.env` in sync.

## Layout

```text
agents/
  hermes_host.py      # QXAudit host (Hermes or hermes_lite)
  embeddings.py       # get_embeddings() from env only
  rag_agent.py        # RAG helper: PDF/Word → Chroma → answer
  rag_bridge_tool.py  # docs_ask tool
  docviewer_agent.py  # DocViewer helper: JSON dispatch
  graph_bridge_tool.py # graph_ask host tool
  neo4j_client.py     # Bolt client
  doc_structure.py    # document structure helpers
tools/
  docviewer/          # DocViewer tools
  graph/              # Neo4j Cypher templates (graph_ask)
prompts/
  hermes_coordinator.md   # QXAudit host system prompt
  rag_agent_system.md     # RAG helper prompt
data/
  docs/               # drop PDF/DOCX/MD/TXT here
  rag/chroma/         # per-model Chroma indexes
```
