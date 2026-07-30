"""
FastAPI — QXAudit (host + helper agents).

  Open WebUI → Gateway → POST /v1/chat
       → QXAudit host (context/memory)
            → tool docs_ask → RAG helper agent → Chroma

  Direct RAG: POST /v1/docs/chat
  DocViewer:  POST /v1/docviewer/run  (JSON document + tools)
"""

from __future__ import annotations

import hashlib
import logging
import os
import secrets
import time
import uuid
from typing import Any, AsyncIterator, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field

from app import __version__

logger = logging.getLogger("app")


class ChatRequest(BaseModel):
    """QXAudit chat body (gateway Open WebUI platform)."""

    message: str = Field(..., min_length=1, description="User question")
    session_id: Optional[str] = Field(
        default=None,
        description="Multi-turn session id (QXAudit host memory)",
    )
    reset_session: bool = Field(
        default=False,
        description="Clear QXAudit host session history",
    )


class ChatResponse(BaseModel):
    success: bool
    response: Optional[str] = None
    session_id: Optional[str] = None
    error: Optional[str] = None
    error_code: Optional[str] = None
    error_detail: Optional[str] = None
    retryable: Optional[bool] = None
    tools_called: Optional[list[dict[str, Any]]] = None
    tool_call_count: Optional[int] = None
    agents_used: Optional[list[str]] = None
    mode: Optional[str] = None
    backend: Optional[str] = None
    sources: Optional[list[dict[str, Any]]] = None


class DocsChatRequest(BaseModel):
    message: str = Field(..., min_length=1, description="Document question")
    session_id: Optional[str] = Field(
        default=None,
        description="Optional client correlation id (RAG is stateless in v1)",
    )


class DocsChatResponse(BaseModel):
    success: bool
    response: Optional[str] = None
    session_id: Optional[str] = None
    error: Optional[str] = None
    error_code: Optional[str] = None
    error_detail: Optional[str] = None
    retryable: Optional[bool] = None
    sources: Optional[list[dict[str, Any]]] = None
    agents_used: Optional[list[str]] = None
    mode: Optional[str] = None
    backend: Optional[str] = None
    embed_provider: Optional[str] = None
    embed_model: Optional[str] = None
    embed_dim: Optional[int] = None


class DocViewerRequest(BaseModel):
    """JSON document for DocViewer agent (+ optional tools to run)."""

    document: Any = Field(
        ...,
        description="JSON object/array, or a JSON string",
    )
    tools: Optional[list[str]] = Field(
        default=None,
        description=(
            "Tool names to run, e.g. "
            "['metadata_extractor', 'knowledge_graph_builder']"
        ),
    )
    run_all: bool = Field(
        default=False,
        description="If true, run every registered DocViewer tool",
    )


class DocViewerResponse(BaseModel):
    success: bool
    agent: Optional[str] = None
    mode: Optional[str] = None
    agents_used: Optional[list[str]] = None
    input_type: Optional[str] = None
    tools_available: Optional[list[str]] = None
    tools_requested: Optional[list[str]] = None
    tools_unknown: Optional[list[str]] = None
    tool_results: Optional[list[dict[str, Any]]] = None
    document_echo: Optional[Any] = None
    message: Optional[str] = None
    timestamp: Optional[str] = None
    error: Optional[str] = None
    error_code: Optional[str] = None
    retryable: Optional[bool] = None


# --- OpenAI-compatible (Open WebUI Gateway Accounting → /v1/chat/completions) ---


class OpenAIChatMessage(BaseModel):
    role: str
    content: Optional[Any] = None

    model_config = {"extra": "allow"}


class OpenAIChatCompletionsRequest(BaseModel):
    model: str = "QXAudit"
    messages: list[OpenAIChatMessage] = Field(default_factory=list)
    stream: bool = False
    temperature: Optional[float] = None
    # Gateway / Open WebUI often forward session ids here
    session_id: Optional[str] = None
    user: Optional[str] = None
    chat_id: Optional[str] = None

    model_config = {"extra": "allow"}


def _content_to_text(content: Any) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for p in content:
            if isinstance(p, dict):
                if p.get("type") == "text":
                    parts.append(str(p.get("text") or ""))
                elif "text" in p:
                    parts.append(str(p.get("text") or ""))
            else:
                parts.append(str(p))
        return " ".join(x for x in parts if x).strip()
    return str(content)


def _last_user_text(messages: list[OpenAIChatMessage]) -> str:
    for msg in reversed(messages or []):
        if (msg.role or "").lower() == "user":
            return _content_to_text(msg.content).strip()
    if messages:
        return _content_to_text(messages[-1].content).strip()
    return ""


def _first_user_text(messages: list[OpenAIChatMessage]) -> str:
    for msg in messages or []:
        if (msg.role or "").lower() == "user":
            return _content_to_text(msg.content).strip()
    return ""


def _prior_turns_for_seed(
    messages: list[OpenAIChatMessage],
) -> list[tuple[str, str]]:
    """All turns except the last user message — for seeding host session."""
    if not messages:
        return []
    # Drop trailing user message (current turn)
    trimmed = list(messages)
    while trimmed and (trimmed[-1].role or "").lower() != "user":
        trimmed.pop()
    if trimmed and (trimmed[-1].role or "").lower() == "user":
        trimmed = trimmed[:-1]
    out: list[tuple[str, str]] = []
    for m in trimmed:
        role = (m.role or "").lower()
        if role == "system":
            continue
        text = _content_to_text(m.content).strip()
        if text:
            out.append((role, text))
    return out


def _resolve_session_id(
    body: OpenAIChatCompletionsRequest,
    request: Request | None = None,
) -> tuple[Optional[str], str]:
    """
    Resolve session id for multi-turn memory.

    Sources (first match):
      body.session_id / chat_id / user
      headers: X-OpenWebUI-Chat-Id, X-Chat-Id, X-Session-Id
      fingerprint of model + first user message (stable within a thread)
    Returns (session_id, source_label).
    """
    for val, src in (
        (body.session_id, "body.session_id"),
        (body.chat_id, "body.chat_id"),
        (body.user, "body.user"),
    ):
        if val and str(val).strip():
            return str(val).strip(), src

    if request is not None:
        headers = request.headers
        for name, src in (
            ("x-openwebui-chat-id", "header.x-openwebui-chat-id"),
            ("x-chat-id", "header.x-chat-id"),
            ("x-session-id", "header.x-session-id"),
            ("x-openwebui-user-id", "header.x-openwebui-user-id"),
        ):
            raw = headers.get(name)
            if raw and raw.strip():
                return raw.strip(), src

    first = _first_user_text(body.messages)
    if first:
        raw = f"{body.model}|{first}".encode("utf-8")
        sid = "owui-" + hashlib.sha256(raw).hexdigest()[:32]
        return sid, "fingerprint"

    return None, "none"


def _openai_completion_payload(
    *,
    model: str,
    text: str,
    completion_id: str,
    created: int,
) -> dict[str, Any]:
    return {
        "id": completion_id,
        "object": "chat.completion",
        "created": created,
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": text},
                "finish_reason": "stop",
            }
        ],
        "usage": {
            "prompt_tokens": 0,
            "completion_tokens": 0,
            "total_tokens": 0,
        },
    }


async def _openai_sse_stream(
    *,
    model: str,
    text: str,
    completion_id: str,
    created: int,
) -> AsyncIterator[str]:
    import json as _json

    # Single-chunk stream (host is non-streaming internally)
    chunk = {
        "id": completion_id,
        "object": "chat.completion.chunk",
        "created": created,
        "model": model,
        "choices": [
            {
                "index": 0,
                "delta": {"role": "assistant", "content": text},
                "finish_reason": None,
            }
        ],
    }
    yield f"data: {_json.dumps(chunk, ensure_ascii=False)}\n\n"
    done = {
        "id": completion_id,
        "object": "chat.completion.chunk",
        "created": created,
        "model": model,
        "choices": [
            {
                "index": 0,
                "delta": {},
                "finish_reason": "stop",
            }
        ],
    }
    yield f"data: {_json.dumps(done, ensure_ascii=False)}\n\n"
    yield "data: [DONE]\n\n"


def _cors_origins() -> list[str]:
    raw = os.getenv("CORS_ORIGINS", "*").strip()
    if raw == "*":
        return ["*"]
    return [o.strip() for o in raw.split(",") if o.strip()]


def _check_bearer(
    authorization: Optional[str] = Header(default=None),
) -> None:
    expected = os.getenv("API_BEARER_TOKEN", "").strip()
    if not expected:
        return
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization.split(" ", 1)[1].strip()
    if not secrets.compare_digest(token, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )


def create_app() -> FastAPI:
    app = FastAPI(
        title=os.getenv("APP_NAME", "QXAudit"),
        version=__version__,
        description=(
            "QXAudit — main host agent + helper agents (RAG, DocViewer). "
            "Direct RAG: POST /v1/docs/*; DocViewer: POST /v1/docviewer/*. "
            "Open WebUI gateway compatible (POST /v1/chat)."
        ),
        docs_url="/docs",
        redoc_url="/redoc",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins(),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.on_event("startup")
    def _startup() -> None:
        logger.info("Starting QXAudit service v%s", __version__)
        try:
            from agents.hermes_host import get_hermes_host

            host = get_hermes_host()
            logger.info("QXAudit host readiness: %s", host.readiness())
        except Exception:
            logger.exception("QXAudit host init failed — /ready may be 503")
        # RAG must never crash the process (Chroma can raise Rust PanicException).
        try:
            from agents.rag_agent import get_rag_agent, is_enabled as rag_enabled

            if rag_enabled():
                rag = get_rag_agent()
                logger.info("RAG readiness: %s", rag.readiness())
        except BaseException as exc:
            if isinstance(exc, (KeyboardInterrupt, SystemExit)):
                raise
            logger.exception(
                "RAG init failed at startup (non-fatal): %s — /v1/docs/* may need reindex",
                exc,
            )
        try:
            from agents.docviewer_agent import (
                get_docviewer_agent,
                is_enabled as docviewer_enabled,
            )

            if docviewer_enabled():
                dv = get_docviewer_agent()
                logger.info("DocViewer readiness: %s", dv.readiness())
        except Exception:
            logger.exception("DocViewer init failed at startup (non-fatal)")

    @app.get("/health")
    def health() -> dict[str, Any]:
        return {"status": "ok", "service": os.getenv("APP_NAME", "QXAudit")}

    @app.get("/ready")
    def ready() -> dict[str, Any]:
        from agents.hermes_host import get_hermes_host

        host = get_hermes_host()
        if not host.ready:
            host.initialize()
        rd = host.readiness()
        if not rd.get("ready"):
            raise HTTPException(
                status_code=503,
                detail={"status": "not_ready", "host": rd},
            )
        return {"status": "ready", "host": rd}

    @app.get("/v1/docs/ready")
    def docs_ready() -> dict[str, Any]:
        from agents.rag_agent import get_rag_agent, is_enabled

        if not is_enabled():
            raise HTTPException(
                status_code=503,
                detail={"status": "disabled", "error": "RAG_ENABLED=false"},
            )
        rag = get_rag_agent()
        if not rag.ready:
            rag.initialize()
        rd = rag.readiness()
        if not rd.get("ready"):
            raise HTTPException(
                status_code=503,
                detail={"status": "not_ready", "rag": rd},
            )
        return {"status": "ready", "rag": rd}

    @app.get("/v1/docs/info")
    def docs_info() -> dict[str, Any]:
        from agents.rag_agent import get_rag_agent, is_enabled

        rag = get_rag_agent()
        return {
            "service": os.getenv("APP_NAME", "QXAudit"),
            "version": __version__,
            "design": "qxaudit-rag",
            "enabled": is_enabled(),
            "docs_chat_path": "/v1/docs/chat",
            "reindex_path": "/v1/docs/reindex",
            "rag": rag.readiness(),
        }

    @app.get("/v1/docs/files")
    def docs_files() -> dict[str, Any]:
        from agents.rag_agent import get_rag_agent

        return get_rag_agent().list_files()

    @app.post("/v1/docs/reindex")
    def docs_reindex(
        _: None = Depends(_check_bearer),
    ) -> dict[str, Any]:
        """Full rebuild of Chroma for the current RAG_EMBED_* identity."""
        from agents.rag_agent import get_rag_agent, is_enabled

        if not is_enabled():
            raise HTTPException(
                status_code=503,
                detail={"success": False, "error": "RAG_ENABLED=false"},
            )
        rag = get_rag_agent()
        logger.info("POST /v1/docs/reindex")
        result = rag.reindex(force=True)
        if not result.get("success"):
            raise HTTPException(status_code=500, detail=result)
        return result

    @app.post("/v1/docs/chat", response_model=DocsChatResponse)
    def docs_chat(
        body: DocsChatRequest,
        _: None = Depends(_check_bearer),
    ) -> DocsChatResponse:
        """Direct document RAG (bypasses QXAudit host)."""
        from agents.rag_agent import get_rag_agent, is_enabled

        if not is_enabled():
            return DocsChatResponse(
                success=False,
                response=None,
                session_id=body.session_id,
                error="RAG disabled (RAG_ENABLED=false)",
                error_code="disabled",
                sources=[],
            )
        try:
            rag = get_rag_agent()
            logger.info(
                "POST /v1/docs/chat msg_len=%d preview=%r",
                len(body.message or ""),
                (body.message or "")[:80],
            )
            result = rag.chat(body.message)
        except Exception as exc:  # noqa: BLE001
            logger.error("docs chat failed: %s", exc, exc_info=True)
            return DocsChatResponse(
                success=False,
                response=None,
                session_id=body.session_id,
                error="Ichki server xatosi (RAG). Iltimos keyinroq urinib ko'ring.",
                error_code="internal",
                error_detail=str(exc)[:500],
                retryable=True,
                sources=[],
            )
        return DocsChatResponse(
            success=bool(result.get("success")),
            response=result.get("response"),
            session_id=body.session_id,
            error=result.get("error"),
            error_code=result.get("error_code"),
            error_detail=result.get("error_detail"),
            retryable=result.get("retryable"),
            sources=result.get("sources"),
            agents_used=result.get("agents_used"),
            mode=result.get("mode"),
            backend=result.get("backend"),
            embed_provider=result.get("embed_provider"),
            embed_model=result.get("embed_model"),
            embed_dim=result.get("embed_dim"),
        )

    @app.get("/v1/docviewer/ready")
    def docviewer_ready() -> dict[str, Any]:
        from agents.docviewer_agent import get_docviewer_agent, is_enabled

        if not is_enabled():
            raise HTTPException(
                status_code=503,
                detail={"status": "disabled", "error": "DOCVIEWER_ENABLED=false"},
            )
        dv = get_docviewer_agent()
        if not dv.ready:
            dv.initialize()
        rd = dv.readiness()
        if not rd.get("ready"):
            raise HTTPException(
                status_code=503,
                detail={"status": "not_ready", "docviewer": rd},
            )
        return {"status": "ready", "docviewer": rd}

    @app.get("/v1/docviewer/info")
    def docviewer_info() -> dict[str, Any]:
        from agents.docviewer_agent import get_docviewer_agent, is_enabled, list_tools

        dv = get_docviewer_agent()
        return {
            "service": os.getenv("APP_NAME", "QXAudit"),
            "version": __version__,
            "agent": "QXAudit.docviewer",
            "enabled": is_enabled(),
            "input": "json",
            "run_path": "/v1/docviewer/run",
            "tools": list_tools(),
            "docviewer": dv.readiness(),
        }

    @app.get("/v1/docviewer/tools")
    def docviewer_tools() -> dict[str, Any]:
        from agents.docviewer_agent import list_tools

        return {"agent": "QXAudit.docviewer", "tools": list_tools()}

    @app.post("/v1/docviewer/run", response_model=DocViewerResponse)
    def docviewer_run(
        body: DocViewerRequest,
        _: None = Depends(_check_bearer),
    ) -> DocViewerResponse:
        """Run DocViewer on a JSON document (tools are stubs until implemented)."""
        from agents.docviewer_agent import get_docviewer_agent, is_enabled

        if not is_enabled():
            return DocViewerResponse(
                success=False,
                agent="QXAudit.docviewer",
                error="DocViewer disabled (DOCVIEWER_ENABLED=false)",
                error_code="disabled",
            )
        try:
            dv = get_docviewer_agent()
            logger.info(
                "POST /v1/docviewer/run tools=%s run_all=%s",
                body.tools,
                body.run_all,
            )
            result = dv.process(
                body.document,
                tools=body.tools,
                run_all=body.run_all,
            )
        except Exception as exc:  # noqa: BLE001
            logger.error("docviewer run failed: %s", exc, exc_info=True)
            return DocViewerResponse(
                success=False,
                agent="QXAudit.docviewer",
                error="Ichki server xatosi (DocViewer).",
                error_code="internal",
                retryable=True,
            )
        return DocViewerResponse(
            success=bool(result.get("success")),
            agent=result.get("agent"),
            mode=result.get("mode"),
            agents_used=result.get("agents_used"),
            input_type=result.get("input_type"),
            tools_available=result.get("tools_available"),
            tools_requested=result.get("tools_requested"),
            tools_unknown=result.get("tools_unknown"),
            tool_results=result.get("tool_results"),
            document_echo=result.get("document_echo"),
            message=result.get("message"),
            timestamp=result.get("timestamp"),
            error=result.get("error"),
            error_code=result.get("error_code"),
            retryable=result.get("retryable"),
        )

    @app.get("/v1/info")
    def info() -> dict[str, Any]:
        from agents.hermes_host import get_hermes_host

        host = get_hermes_host()
        rd = host.readiness()
        rag_rd: dict[str, Any] = {}
        try:
            from agents.rag_agent import get_rag_agent, is_enabled as rag_enabled

            rag_rd = {
                "enabled": rag_enabled(),
                "path": "/v1/docs/chat",
                "tool": "docs_ask",
                **(
                    {k: get_rag_agent().readiness().get(k) for k in (
                        "ready",
                        "identity",
                        "chunk_count",
                        "error",
                    )}
                    if rag_enabled()
                    else {}
                ),
            }
        except Exception as exc:  # noqa: BLE001
            rag_rd = {"enabled": False, "error": str(exc)}
        docviewer_rd: dict[str, Any] = {}
        try:
            from agents.docviewer_agent import (
                get_docviewer_agent,
                is_enabled as docviewer_enabled,
            )

            docviewer_rd = {
                "enabled": docviewer_enabled(),
                "path": "/v1/docviewer/run",
                "agent": "QXAudit.docviewer",
                **(
                    {
                        k: get_docviewer_agent().readiness().get(k)
                        for k in ("ready", "tools", "error")
                    }
                    if docviewer_enabled()
                    else {}
                ),
            }
        except Exception as exc:  # noqa: BLE001
            docviewer_rd = {"enabled": False, "error": str(exc)}
        return {
            "service": os.getenv("APP_NAME", "QXAudit"),
            "version": __version__,
            "design": "qxaudit-host-helpers",
            "agent": "QXAudit",
            "architecture": rd.get("architecture"),
            "backend": rd.get("backend"),
            "gateway_compatible": True,
            "chat_path": "/v1/chat",
            "openai_chat_path": "/v1/chat/completions",
            "tool": "docs_ask",
            "helpers": {
                "rag": rd.get("rag_agent"),
                "docviewer": docviewer_rd,
            },
            "inner_rag": rd.get("rag_agent"),
            "ready": host.ready,
            "model": rd.get("model"),
            "rag": rag_rd,
            "docviewer": docviewer_rd,
        }

    @app.post("/v1/chat", response_model=ChatResponse)
    def chat(
        body: ChatRequest,
        _: None = Depends(_check_bearer),
    ) -> ChatResponse:
        """Gateway entry (message API): QXAudit host + docs_ask."""
        from agents.hermes_host import get_hermes_host

        try:
            host = get_hermes_host()
            logger.info(
                "POST /v1/chat session_id=%r reset=%s msg_len=%d msg_preview=%r",
                body.session_id,
                body.reset_session,
                len(body.message or ""),
                (body.message or "")[:80],
            )
            result = host.chat(
                body.message,
                session_id=body.session_id,
                reset_session=body.reset_session,
            )
        except Exception as exc:  # noqa: BLE001
            logger.error("chat endpoint failed: %s", exc, exc_info=True)
            return ChatResponse(
                success=False,
                response=None,
                session_id=body.session_id,
                error="Ichki server xatosi. Iltimos keyinroq urinib ko'ring.",
                error_code="internal",
                error_detail=str(exc)[:500],
                retryable=True,
            )
        return ChatResponse(
            success=bool(result.get("success")),
            response=result.get("response"),
            session_id=result.get("session_id") or body.session_id,
            error=result.get("error"),
            error_code=result.get("error_code"),
            error_detail=result.get("error_detail"),
            retryable=result.get("retryable"),
            tools_called=result.get("tools_called"),
            tool_call_count=result.get("tool_call_count"),
            agents_used=result.get("agents_used"),
            mode=result.get("mode"),
            backend=result.get("backend"),
            sources=result.get("sources"),
        )

    @app.get("/v1/self-improve")
    def self_improve_stats() -> dict[str, Any]:
        """Global learned Q/A recipe store stats."""
        from agents import self_improve

        return self_improve.stats()

    @app.get("/v1/graph/ready")
    def graph_ready() -> dict[str, Any]:
        from agents.neo4j_client import readiness

        rd = readiness()
        if not rd.get("ready"):
            raise HTTPException(
                status_code=503,
                detail={"status": "not_ready", "neo4j": rd},
            )
        return {"status": "ready", "neo4j": rd}

    @app.get("/v1/graph/intents")
    def graph_intents() -> dict[str, Any]:
        from tools.graph import list_intents

        return {"tool": "graph_ask", "intents": list_intents()}

    class GraphAskRequest(BaseModel):
        question: str = Field(default="", description="User question")
        intent: str = Field(default="auto")
        name: str = Field(default="")
        code: str = Field(default="")
        number: Optional[int] = Field(default=None)

    @app.post("/v1/graph/ask")
    def graph_ask_api(
        body: GraphAskRequest,
        _: None = Depends(_check_bearer),
    ) -> dict[str, Any]:
        """Direct graph_ask (template Cypher) — debug / clients without host."""
        from tools.graph.service import format_for_host, graph_ask

        result = graph_ask(
            question=body.question,
            intent=body.intent or "auto",
            name=body.name,
            code=body.code,
            number=body.number,
        )
        result["text"] = format_for_host(result)
        return result

    @app.post("/v1/chat/completions")
    def chat_completions(
        body: OpenAIChatCompletionsRequest,
        request: Request,
        _: None = Depends(_check_bearer),
    ):
        """
        OpenAI-compatible entry for Open WebUI Gateway agents
        (e.g. Accounting with endpoint /v1/chat/completions).

        Adapts messages[] → QXAudit host.chat(message, session_id=...).
        Session id: body → Open WebUI headers → fingerprint of first user turn.
        """
        from agents.hermes_host import get_hermes_host

        user_text = _last_user_text(body.messages)
        session_id, session_src = _resolve_session_id(body, request)
        model = body.model or "QXAudit"
        completion_id = f"chatcmpl-{uuid.uuid4().hex[:24]}"
        created = int(time.time())

        if not user_text:
            err = "messages must include a non-empty user message"
            if body.stream:
                return StreamingResponse(
                    _openai_sse_stream(
                        model=model,
                        text=err,
                        completion_id=completion_id,
                        created=created,
                    ),
                    media_type="text/event-stream",
                )
            return JSONResponse(
                status_code=400,
                content={"error": {"message": err, "type": "invalid_request_error"}},
            )

        try:
            host = get_hermes_host()
            # Seed memory from Open WebUI transcript if this session is new
            if session_id:
                prior = _prior_turns_for_seed(body.messages)
                if prior:
                    host.seed_session_history(session_id, prior)
            logger.info(
                "POST /v1/chat/completions model=%r session_id=%r session_src=%s "
                "msg_len=%d history_msgs=%d preview=%r stream=%s",
                model,
                session_id,
                session_src,
                len(user_text),
                len(body.messages or []),
                user_text[:80],
                body.stream,
            )
            result = host.chat(user_text, session_id=session_id)
        except Exception as exc:  # noqa: BLE001
            logger.error("chat/completions failed: %s", exc, exc_info=True)
            text = f"Ichki server xatosi: {exc}"
            if body.stream:
                return StreamingResponse(
                    _openai_sse_stream(
                        model=model,
                        text=text,
                        completion_id=completion_id,
                        created=created,
                    ),
                    media_type="text/event-stream",
                )
            return JSONResponse(
                status_code=500,
                content={"error": {"message": text, "type": "server_error"}},
            )

        if not result.get("success"):
            text = (
                result.get("error")
                or result.get("error_detail")
                or "QXAudit host failed"
            )
        else:
            text = (result.get("response") or "").strip() or "(empty response)"

        if body.stream:
            return StreamingResponse(
                _openai_sse_stream(
                    model=model,
                    text=text,
                    completion_id=completion_id,
                    created=created,
                ),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no",
                    "X-QXAudit-Session-Id": str(result.get("session_id") or session_id or ""),
                    "X-QXAudit-Session-Source": session_src,
                },
            )

        payload = _openai_completion_payload(
            model=model,
            text=text,
            completion_id=completion_id,
            created=created,
        )
        # Non-standard but useful for debugging gateway session wiring
        payload["qxaudit_session_id"] = result.get("session_id") or session_id
        payload["qxaudit_session_source"] = session_src
        return JSONResponse(content=payload)

    return app


app = create_app()
