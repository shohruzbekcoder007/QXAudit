"""
QXAudit main host agent + document RAG helper tool.

Architecture:

  User → QXAudit host (conversation + memory)
            └─ tool docs_ask → RAG helper agent → Chroma (PDF / Word / FAQ)

If the Hermes package is unavailable, a hermes_lite outer loop is used
(same design: host tool-calling loop + docs_ask tool + session history).
"""

from __future__ import annotations

import logging
import os
import threading
import time
import uuid
from pathlib import Path
from typing import Any, Optional

logger = logging.getLogger("hermes_host")

_lock = threading.RLock()
_service: Optional["HermesHostService"] = None


def _env(name: str, default: str = "") -> str:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip()


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None or not str(raw).strip():
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _load_coordinator_prompt() -> str:
    path = Path(
        _env("HERMES_SYSTEM_PROMPT_PATH")
        or str(
            Path(__file__).resolve().parent.parent
            / "prompts"
            / "hermes_coordinator.md"
        )
    )
    if path.is_file():
        return path.read_text(encoding="utf-8")
    return (
        "You are QXAudit, the main host agent. Use the docs_ask tool for "
        "document and policy questions. Never invent facts from documents."
    )


class HermesHostService:
    """
    QXAudit host agent with session memory. Tool docs_ask → RAG helper.
    """

    name = "QXAudit"

    def __init__(self) -> None:
        from agents.llm_config import get_llm_settings

        llm = get_llm_settings()
        self.llm_provider = llm["provider"]
        # HERMES_MODEL / HERMES_BASE_URL stay as explicit overrides
        self.model_name = _env("HERMES_MODEL") or llm["model"]
        self.api_key = llm["api_key"]
        self.base_url = _env("HERMES_BASE_URL") or llm["base_url"]
        self.task_model = llm["task_model"]
        self.max_iterations = _env_int("HERMES_MAX_ITERATIONS", 12)
        self.session_limit = _env_int("HERMES_SESSION_HISTORY_LIMIT", 6)
        self.skip_memory = _env_bool("HERMES_SKIP_MEMORY", False)
        self.system_prompt = _load_coordinator_prompt()
        self._backend: str | None = None  # hermes | hermes_lite
        self._ready = False
        self._last_error: str | None = None
        self._sessions: dict[str, list[Any]] = {}
        # Backends are independent: either one alone is enough to serve.
        self._rag_ready = False
        self._graph_ready = False
        self._rag_error: str | None = None
        self._graph_error: str | None = None
        self._last_probe_ts = 0.0
        self.recover_interval = _env_int("HERMES_RECOVER_INTERVAL_SECONDS", 60)
        # hermes_lite: langgraph graph; hermes: factory for AIAgent
        self._lite_graph: Any = None
        self._hermes_ok = False

    def initialize(self) -> dict[str, Any]:
        with _lock:
            if self._ready:
                return self.readiness()

            if not self.api_key:
                self._last_error = (
                    f"LLM api_key not set (provider={self.llm_provider}; "
                    "openai: OPENAI_API_KEY, ollama: avtomatik)"
                )
                self._ready = False
                return self.readiness()

            # Warm RAG agent (tool target). RAG is OPTIONAL: if the embedding
            # service is down, docs_ask is dropped but graph_ask keeps working.
            self._rag_ready = self._probe_rag()
            self._graph_ready = self._probe_graph()
            if not self._rag_ready and not self._graph_ready:
                self._last_error = (
                    "No knowledge backend available — "
                    f"rag: {self._rag_error}; graph: {self._graph_error}"
                )
                self._ready = False
                logger.error("%s", self._last_error)
                return self.readiness()
            if not self._rag_ready:
                logger.warning(
                    "QXAudit host starting WITHOUT docs_ask (RAG): %s — "
                    "graph_ask only (degraded mode)",
                    self._rag_error,
                )
            if not self._graph_ready:
                logger.warning(
                    "QXAudit host starting WITHOUT graph_ask (Neo4j): %s — "
                    "docs_ask only (degraded mode)",
                    self._graph_error,
                )

            # Register Hermes tools if possible
            try:
                from agents.rag_bridge_tool import register_hermes_tools as register_docs_tools

                register_docs_tools()
            except Exception as exc:  # noqa: BLE001
                logger.debug("register_docs_tools: %s", exc)

            try:
                from agents.graph_bridge_tool import (
                    register_hermes_tools as register_graph_tools,
                )
                from agents.reconcile_bridge_tool import (
                    register_hermes_tools as register_reconcile_tools,
                )

                register_graph_tools()
                register_reconcile_tools()
            except Exception as exc:  # noqa: BLE001
                logger.debug("register_graph_tools: %s", exc)

            try:
                from hermes_cli.plugins import discover_plugins  # type: ignore

                discover_plugins()
            except Exception as exc:  # noqa: BLE001
                logger.debug("discover_plugins: %s", exc)

            # Prefer real Hermes AIAgent
            if self._try_init_hermes():
                self._backend = "hermes"
                self._ready = True
                self._last_error = None
                logger.info("QXAudit host ready (backend=hermes model=%s)", self.model_name)
                return self.readiness()

            # Hermes-lite: same architecture without hermes package
            if self._try_init_hermes_lite():
                self._backend = "hermes_lite"
                self._ready = True
                self._last_error = None
                logger.info(
                    "QXAudit host ready (backend=hermes_lite model=%s) — "
                    "Hermes package missing or failed; using tool-calling host",
                    self.model_name,
                )
                return self.readiness()

            self._ready = False
            self._last_error = self._last_error or "Failed to init QXAudit host"
            return self.readiness()

    def _probe_rag(self) -> bool:
        """Best-effort RAG warm-up. Never raises; records self._rag_error."""
        self._rag_error = None
        try:
            from agents.rag_agent import get_rag_agent, is_enabled as rag_enabled

            if not rag_enabled():
                self._rag_error = "RAG disabled (RAG_ENABLED=false)"
                return False
            rag = get_rag_agent()
            if not rag.ready:
                rag.initialize()
            if not rag.ready:
                self._rag_error = str(
                    rag.readiness().get("error") or "RAG agent not ready"
                )
                return False
            return True
        except BaseException as exc:  # noqa: BLE001 — Chroma can raise PanicException
            if isinstance(exc, (KeyboardInterrupt, SystemExit)):
                raise
            self._rag_error = str(exc)
            return False

    def _probe_graph(self) -> bool:
        """Best-effort Neo4j check. Never raises; records self._graph_error."""
        self._graph_error = None
        try:
            from agents.neo4j_client import is_enabled as neo4j_on, readiness

            if not neo4j_on():
                self._graph_error = "Neo4j disabled (NEO4J_ENABLED=false)"
                return False
            rd = readiness()
            if not rd.get("ready"):
                self._graph_error = str(rd.get("error") or "Neo4j not ready")
                return False
            return True
        except Exception as exc:  # noqa: BLE001
            self._graph_error = str(exc)
            return False

    def _maybe_recover(self) -> None:
        """
        Re-attach a backend that came back online.

        Probe rate is bounded by HERMES_RECOVER_INTERVAL_SECONDS so a permanently
        dead service does not add latency to every chat turn.
        """
        if self._rag_ready and self._graph_ready:
            return
        now = time.monotonic()
        if now - self._last_probe_ts < self.recover_interval:
            return
        self._last_probe_ts = now
        before = (self._rag_ready, self._graph_ready)
        after = (self._probe_rag(), self._probe_graph())
        self._rag_ready, self._graph_ready = after
        if after != before:
            logger.info(
                "Backend availability changed rag=%s→%s graph=%s→%s — rebuilding host",
                before[0], after[0], before[1], after[1],
            )
            self._ready = False
            self.initialize()

    def _try_init_hermes(self) -> bool:
        try:
            from run_agent import AIAgent  # type: ignore[import-not-found]

            # Smoke-construct (don't store shared AIAgent — not always thread-safe)
            kwargs = self._hermes_kwargs()
            _ = AIAgent(**kwargs)
            self._hermes_ok = True
            return True
        except Exception as exc:  # noqa: BLE001
            logger.warning("Hermes AIAgent unavailable: %s", exc)
            self._hermes_ok = False
            self._last_error = f"Hermes unavailable: {exc}"
            return False

    def _reasoning_config(self) -> dict[str, Any]:
        """
        Hermes defaults to reasoning.effort which OpenAI gpt-4* / gpt-4.1 reject
        with HTTP 400. Keep off unless explicitly enabled (o-series etc.).
        """
        if _env_bool("HERMES_REASONING_ENABLED", False):
            effort = _env("HERMES_REASONING_EFFORT") or "medium"
            return {"enabled": True, "effort": effort}
        return {"enabled": False}

    def _hermes_kwargs(self) -> dict[str, Any]:
        kwargs: dict[str, Any] = {
            "model": self.model_name,
            "quiet_mode": _env_bool("HERMES_QUIET_MODE", True),
            "max_iterations": self.max_iterations,
            "enabled_toolsets": self._enabled_toolsets(),
            "skip_memory": self.skip_memory,
            "skip_context_files": _env_bool("HERMES_SKIP_CONTEXT_FILES", True),
            "ephemeral_system_prompt": self.system_prompt,
            "platform": "qxaudit",
            "api_key": self.api_key,
            "reasoning_config": self._reasoning_config(),
        }
        if self.base_url:
            kwargs["base_url"] = self.base_url
        return kwargs

    def _enabled_toolsets(self) -> list[str]:
        """
        Toolsets actually offered to the model.

        Only backends that answered a readiness probe are listed — advertising a
        tool whose backend is down makes the model call it and fail.
        """
        raw = _env("HERMES_ENABLED_TOOLSETS") or "docs_bridge,graph_bridge"
        wanted = [t.strip() for t in raw.split(",") if t.strip()]
        # Drop legacy SQL toolset if still listed in env
        wanted = [s for s in wanted if s not in {"sql_bridge", "sql-bridge"}]
        sets: list[str] = []
        if self._rag_ready and "docs_bridge" not in sets:
            sets.append("docs_bridge")
        if self._graph_ready and "graph_bridge" not in sets:
            sets.append("graph_bridge")
        # Keep any extra toolsets the operator configured explicitly
        for s in wanted:
            if s not in {"docs_bridge", "graph_bridge"} and s not in sets:
                sets.append(s)
        return sets

    def _host_langchain_tools(self) -> list[Any]:
        """docs_ask and/or graph_ask — only the backends that are actually up."""
        tools: list[Any] = []
        if self._rag_ready:
            try:
                from agents.rag_bridge_tool import as_langchain_tool as docs_tool

                tools.append(docs_tool())
            except Exception as exc:  # noqa: BLE001
                logger.warning("docs_ask tool not added: %s", exc)
        if self._graph_ready:
            try:
                from agents.graph_bridge_tool import as_langchain_tool as graph_tool

                tools.append(graph_tool())
            except Exception as exc:  # noqa: BLE001
                logger.warning("graph_ask tool not added: %s", exc)
            try:
                from agents.reconcile_bridge_tool import (
                    as_langchain_tool as reconcile_tool,
                )

                tools.append(reconcile_tool())
            except Exception as exc:  # noqa: BLE001
                logger.warning("reconcile_check tool not added: %s", exc)
        return tools

    def _try_init_hermes_lite(self) -> bool:
        try:
            from langchain_openai import ChatOpenAI
            from langgraph.prebuilt import create_react_agent

            llm_kwargs: dict[str, Any] = {
                "model": self.model_name,
                "api_key": self.api_key,
                "temperature": 0,
            }
            if self.base_url:
                llm_kwargs["base_url"] = self.base_url
            llm = ChatOpenAI(**llm_kwargs)
            tools = self._host_langchain_tools()
            self._lite_graph = create_react_agent(
                llm,
                tools,
                prompt=self.system_prompt,
            )
            return True
        except TypeError:
            # older create_react_agent without prompt=
            try:
                from langchain_openai import ChatOpenAI
                from langgraph.prebuilt import create_react_agent

                llm_kwargs = {
                    "model": self.model_name,
                    "api_key": self.api_key,
                    "temperature": 0,
                }
                if self.base_url:
                    llm_kwargs["base_url"] = self.base_url
                llm = ChatOpenAI(**llm_kwargs)
                self._lite_graph = create_react_agent(
                    llm, self._host_langchain_tools()
                )
                return True
            except Exception as exc:  # noqa: BLE001
                self._last_error = f"hermes_lite init failed: {exc}"
                logger.error("%s", self._last_error)
                return False
        except Exception as exc:  # noqa: BLE001
            self._last_error = f"hermes_lite init failed: {exc}"
            logger.error("%s", self._last_error)
            return False

    @property
    def ready(self) -> bool:
        return self._ready

    def readiness(self) -> dict[str, Any]:
        rag_rd: dict[str, Any] = {}
        try:
            from agents.rag_agent import get_rag_agent, is_enabled as rag_enabled

            if rag_enabled():
                rag_rd = get_rag_agent().readiness()
            else:
                rag_rd = {"ready": False, "error": "RAG_ENABLED=false"}
        except BaseException as exc:  # noqa: BLE001
            if isinstance(exc, (KeyboardInterrupt, SystemExit)):
                raise
            rag_rd = {"ready": False, "error": str(exc)}
        if not rag_rd.get("ready") and self._rag_error:
            rag_rd.setdefault("error", self._rag_error)
        tools = self._host_tool_names()
        # One working backend is enough to serve; degraded is still ready.
        serving = self._ready and bool(tools)
        return {
            "ready": serving,
            "degraded": serving and len(tools) < 2,
            "backend": self._backend,
            "host": "QXAudit",
            "agent": "QXAudit",
            "architecture": (
                "QXAudit host → docs_ask (RAG/Chroma) + graph_ask (Neo4j templates)"
            ),
            "model": self.model_name,
            "llm_provider": self.llm_provider,
            "llm_base_url": self.base_url,
            "skip_memory": self.skip_memory,
            "session_count": len(self._sessions),
            "helpers": {"rag": rag_rd, "graph": self._graph_readiness()},
            "rag_agent": rag_rd,
            "error": self._last_error,
            "tools": tools,
            "unavailable": {
                **({"docs_ask": self._rag_error} if not self._rag_ready else {}),
                **({"graph_ask": self._graph_error} if not self._graph_ready else {}),
            },
            "toolsets": self._enabled_toolsets(),
        }

    def _degraded_note(self) -> str:
        """Tell the model which tool is missing, so it stops promising it."""
        missing: list[str] = []
        if not self._rag_ready:
            missing.append(
                "`docs_ask` (hujjat matni) hozir MAVJUD EMAS — uni chaqirma. "
                "Grafdagi ma'lumot bilan javob ber va hujjatning to'liq matni "
                "vaqtincha mavjud emasligini foydalanuvchiga ayt."
            )
        if not self._graph_ready:
            missing.append(
                "`graph_ask` va `reconcile_check` (bilim grafi) hozir MAVJUD EMAS — "
                "ularni chaqirma. "
                "Hujjat matni bilan javob ber va aniq raqam/formulani grafdan "
                "tasdiqlab bo'lmasligini foydalanuvchiga ayt."
            )
        if not missing:
            return ""
        return "\n\n## DEGRADATSIYA (hozirgi holat)\n- " + "\n- ".join(missing) + "\n"

    def _host_tool_names(self) -> list[str]:
        names: list[str] = []
        if self._rag_ready:
            names.append("docs_ask")
        if self._graph_ready:
            names.extend(["graph_ask", "reconcile_check"])
        return names

    def _graph_readiness(self) -> dict[str, Any]:
        try:
            from agents.neo4j_client import readiness as neo4j_ready

            return neo4j_ready()
        except Exception as exc:  # noqa: BLE001
            return {"ready": False, "error": str(exc)}

    def clear_session(self, session_id: str) -> None:
        with _lock:
            self._sessions.pop(session_id, None)

    def chat(
        self,
        message: str,
        *,
        session_id: str | None = None,
        reset_session: bool = False,
    ) -> dict[str, Any]:
        """
        Host chat with optional multi-turn session.
        Never raises to callers.
        """
        try:
            message = (message or "").strip()
            if not message:
                return {
                    "success": False,
                    "response": None,
                    "error": "message must not be empty",
                    "error_code": "validation",
                    "session_id": session_id,
                }

            # Open WebUI housekeeping prompts (title / tags / follow-up
            # suggestions) must never reach the tool agent: they waste a
            # full-model call and push real turns out of the bounded session
            # memory. Answer them with one cheap call, write nothing.
            try:
                from agents.self_improve import is_client_task_prompt

                if is_client_task_prompt(message):
                    return self._chat_meta_task(message, session_id)
            except ImportError:
                pass

            if not self._ready:
                self.initialize()
            else:
                # A backend that was down may be back — re-attach its tool.
                self._maybe_recover()
            if not self._ready:
                return {
                    "success": False,
                    "response": None,
                    "error": self._last_error or "QXAudit host not ready",
                    "error_code": "not_ready",
                    "session_id": session_id,
                }

            client_sid = (session_id or "").strip() or None
            sid = client_sid or str(uuid.uuid4())
            if reset_session:
                self.clear_session(sid)

            prior_len = 0
            with _lock:
                prior_len = len(self._sessions.get(sid, []))
            logger.info(
                "host.chat client_session_id=%r effective_sid=%s prior_history=%d backend=%s",
                client_sid,
                sid,
                prior_len,
                self._backend,
            )

            # Self-improve: inject similar past Q/A into system prompt for this turn
            system_prompt = self.system_prompt
            try:
                from agents import self_improve

                system_prompt = self_improve.augment_system_prompt(
                    self.system_prompt, message
                )
            except Exception as exc:  # noqa: BLE001
                logger.debug("self_improve augment skipped: %s", exc)

            system_prompt = (system_prompt or "") + self._degraded_note()

            if self._backend == "hermes":
                result = self._chat_hermes(message, sid, system_prompt=system_prompt)
            else:
                result = self._chat_hermes_lite(
                    message, sid, system_prompt=system_prompt
                )

            # Learn successful answers (global recipe store)
            try:
                from agents import self_improve

                self_improve.learn_from_result(message, result)
            except Exception as exc:  # noqa: BLE001
                logger.debug("self_improve learn skipped: %s", exc)

            return result
        except Exception as exc:  # noqa: BLE001
            logger.error("hermes_host.chat failed: %s", exc, exc_info=True)
            return {
                "success": False,
                "response": None,
                "error": f"Host agent error: {exc}",
                "error_code": "agent_error",
                "retryable": True,
                "session_id": session_id,
            }

    def seed_session_history(
        self,
        session_id: str,
        turns: list[tuple[str, str]],
    ) -> None:
        """
        Seed in-memory history from external transcript (e.g. Open WebUI messages[]).

        turns: list of (role, text) where role is user|assistant|human|ai.
        Only applied when session has no history yet.
        """
        if self.skip_memory or not session_id or not turns:
            return
        with _lock:
            if self._sessions.get(session_id):
                return
        try:
            from langchain_core.messages import AIMessage, HumanMessage
        except Exception:  # noqa: BLE001
            return

        hist: list[Any] = []
        for role, text in turns:
            text = (text or "").strip()
            if not text:
                continue
            r = (role or "").lower()
            if r in {"user", "human"}:
                hist.append(HumanMessage(content=text))
            elif r in {"assistant", "ai", "model"}:
                hist.append(AIMessage(content=text))
        if not hist:
            return
        limit = max(4, self.session_limit * 2)
        if len(hist) > limit:
            hist = hist[-limit:]
        with _lock:
            if not self._sessions.get(session_id):
                self._sessions[session_id] = hist
                logger.info(
                    "host.seed_session sid=%s turns=%d", session_id, len(hist)
                )

    def _chat_meta_task(
        self,
        message: str,
        session_id: str | None,
    ) -> dict[str, Any]:
        """
        Answer a client housekeeping prompt (title / tags / follow-up
        suggestions) with one cheap LLM call: no tools, no session memory,
        no self-improve. Such prompts carry their own <chat_history> inline,
        so nothing is lost by keeping them out of the host session.
        """
        sid = (session_id or "").strip() or str(uuid.uuid4())
        logger.info(
            "host.chat meta-task short-circuit sid=%s len=%d preview=%r",
            sid,
            len(message),
            message[:60],
        )
        system = (
            "You are a lightweight assistant for UI housekeeping tasks "
            "(chat title, tags, follow-up suggestion generation). Follow the "
            "task's requested output format exactly. No commentary."
        )
        task_model = self.task_model or self.model_name
        last_error: str | None = None
        for model in dict.fromkeys([task_model, self.model_name]):
            try:
                from langchain_core.messages import HumanMessage, SystemMessage
                from langchain_openai import ChatOpenAI

                kwargs: dict[str, Any] = {
                    "model": model,
                    "api_key": self.api_key,
                    "temperature": 0,
                }
                if self.base_url:
                    kwargs["base_url"] = self.base_url
                llm = ChatOpenAI(**kwargs)
                resp = llm.invoke(
                    [SystemMessage(content=system), HumanMessage(content=message)]
                )
                content = getattr(resp, "content", None)
                if isinstance(content, list):
                    text = " ".join(
                        b.get("text", str(b)) if isinstance(b, dict) else str(b)
                        for b in content
                    )
                else:
                    text = str(content or "")
                if not text.strip():
                    last_error = f"empty response from {model}"
                    continue
                return {
                    "success": True,
                    "response": text,
                    "error": None,
                    "session_id": sid,
                    "backend": "task_llm",
                    "model": model,
                    "tool_call_count": 0,
                    "agents_used": ["QXAudit.task"],
                    "mode": "meta_task",
                }
            except Exception as exc:  # noqa: BLE001
                last_error = str(exc)
                logger.warning("meta task model %s failed: %s", model, exc)
        return {
            "success": False,
            "response": None,
            "error": f"meta task failed: {last_error}",
            "error_code": "meta_task_error",
            "session_id": sid,
            "mode": "meta_task",
        }

    def _chat_hermes(
        self,
        message: str,
        sid: str,
        *,
        system_prompt: str | None = None,
    ) -> dict[str, Any]:
        from run_agent import AIAgent  # type: ignore[import-not-found]

        prompt = system_prompt if system_prompt is not None else self.system_prompt
        history: list[Any] | None = None
        with _lock:
            if sid in self._sessions:
                history = list(self._sessions[sid])

        kwargs = self._hermes_kwargs()
        kwargs["ephemeral_system_prompt"] = prompt
        agent = AIAgent(**kwargs)
        try:
            if history:
                result = agent.run_conversation(
                    user_message=message,
                    conversation_history=history,
                    system_message=prompt,
                )
            else:
                result = agent.run_conversation(
                    user_message=message,
                    system_message=prompt,
                )
        except TypeError:
            # older signature
            result = agent.run_conversation(user_message=message)

        if isinstance(result, dict):
            final = result.get("final_response") or result.get("response")
            messages = result.get("messages")
        else:
            final = str(result)
            messages = None

        if messages is not None and not self.skip_memory:
            trimmed = list(messages)
            limit = max(4, self.session_limit * 2)
            if len(trimmed) > limit:
                trimmed = trimmed[-limit:]
            with _lock:
                self._sessions[sid] = trimmed

        return {
            "success": True,
            "response": final,
            "error": None,
            "session_id": sid,
            "backend": "hermes",
            "agents_used": ["QXAudit"] + self._host_tool_names(),
            "mode": "qxaudit_tool_host",
        }

    def _chat_hermes_lite(
        self,
        message: str,
        sid: str,
        *,
        system_prompt: str | None = None,
    ) -> dict[str, Any]:
        from langchain_core.messages import AIMessage, HumanMessage, SystemMessage

        prompt = system_prompt if system_prompt is not None else self.system_prompt
        with _lock:
            prior = list(self._sessions.get(sid, []))

        # Build message list: system + history + user
        messages: list[Any] = [SystemMessage(content=prompt)]
        messages.extend(prior)
        messages.append(HumanMessage(content=message))

        recursion = max(8, self.max_iterations * 2)
        try:
            result = self._lite_graph.invoke(
                {"messages": messages},
                config={"recursion_limit": recursion},
            )
        except TypeError:
            # graph without system in messages — prepend to user
            result = self._lite_graph.invoke(
                {
                    "messages": prior
                    + [HumanMessage(content=f"{prompt}\n\nUser: {message}")]
                },
                config={"recursion_limit": recursion},
            )

        out_msgs = result.get("messages") if isinstance(result, dict) else messages
        final = ""
        if out_msgs:
            last = out_msgs[-1]
            content = getattr(last, "content", None)
            if isinstance(content, list):
                final = " ".join(
                    b.get("text", str(b)) if isinstance(b, dict) else str(b)
                    for b in content
                )
            else:
                final = str(content if content is not None else last)

        # Persist history (human + ai turns only, bounded)
        if not self.skip_memory:
            new_hist = list(prior)
            new_hist.append(HumanMessage(content=message))
            new_hist.append(AIMessage(content=final or ""))
            limit = max(4, self.session_limit * 2)
            if len(new_hist) > limit:
                new_hist = new_hist[-limit:]
            with _lock:
                self._sessions[sid] = new_hist

        # Count tool calls
        tool_hits = 0
        tools_seen: list[str] = []
        for m in out_msgs or []:
            tcs = getattr(m, "tool_calls", None) or []
            for tc in tcs:
                name = tc.get("name") if isinstance(tc, dict) else getattr(tc, "name", "")
                if name in {"docs_ask", "graph_ask", "reconcile_check"}:
                    tool_hits += 1
                    if name not in tools_seen:
                        tools_seen.append(str(name))

        return {
            "success": bool((final or "").strip()),
            "response": final or None,
            "error": None if (final or "").strip() else "Empty host response",
            "session_id": sid,
            "backend": "hermes_lite",
            "tool_call_count": tool_hits,
            "agents_used": ["QXAudit"] + (tools_seen or self._host_tool_names()),
            "mode": "qxaudit_tool_hybrid",
        }


def get_hermes_host() -> HermesHostService:
    global _service
    with _lock:
        if _service is None:
            _service = HermesHostService()
            _service.initialize()
        elif not _service.ready:
            _service.initialize()
        return _service
