"""
QXAudit DocViewer agent (primitive).

Accepts a JSON document and dispatches to tools under
``tools/docviewer/`` (one file per tool, separate from agents/).
"""

from __future__ import annotations

import json
import logging
import os
import threading
from datetime import datetime, timezone
from typing import Any, Optional

from tools.docviewer import (
    get_handler,
    known_tool_names,
    list_tools,
)

logger = logging.getLogger("docviewer")

_lock = threading.RLock()
_service: Optional["DocViewerAgentService"] = None


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def is_enabled() -> bool:
    return _env_bool("DOCVIEWER_ENABLED", True)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _parse_json_input(document: Any) -> tuple[Optional[Any], Optional[str]]:
    """
    Accept dict/list already parsed, or a JSON string.
    Returns (parsed, error).
    """
    if document is None:
        return None, "document is required (JSON object/array or JSON string)"
    if isinstance(document, (dict, list)):
        return document, None
    if isinstance(document, (bytes, bytearray)):
        try:
            document = document.decode("utf-8")
        except Exception as exc:  # noqa: BLE001
            return None, f"document bytes decode failed: {exc}"
    if isinstance(document, str):
        text = document.strip()
        if not text:
            return None, "document string is empty"
        try:
            return json.loads(text), None
        except json.JSONDecodeError as exc:
            return None, f"invalid JSON: {exc}"
    return None, f"document must be JSON object/array or string, got {type(document).__name__}"


class DocViewerAgentService:
    """
    QXAudit.docviewer — JSON-in agent with pluggable internal tools.
    """

    name = "QXAudit.docviewer"

    def __init__(self) -> None:
        self._ready = False
        self._last_error: str | None = None

    @property
    def ready(self) -> bool:
        return self._ready and is_enabled()

    def initialize(self) -> dict[str, Any]:
        with _lock:
            if not is_enabled():
                self._ready = False
                self._last_error = "DOCVIEWER_ENABLED=false"
                return self.readiness()
            self._ready = True
            self._last_error = None
            logger.info(
                "DocViewer agent ready tools=%s",
                [t["name"] for t in list_tools()],
            )
            return self.readiness()

    def readiness(self) -> dict[str, Any]:
        return {
            "ready": self.ready,
            "enabled": is_enabled(),
            "agent": self.name,
            "input": "json",
            "tools": list_tools(),
            "error": self._last_error,
        }

    def process(
        self,
        document: Any,
        *,
        tools: list[str] | None = None,
        run_all: bool = False,
    ) -> dict[str, Any]:
        """
        Accept a JSON document and run selected tools (stubs for now).

        Args:
            document: dict/list or JSON string
            tools: tool names to run (default: none unless run_all)
            run_all: if True, run every registered tool
        """
        try:
            if not is_enabled():
                return {
                    "success": False,
                    "agent": self.name,
                    "error": "DocViewer disabled (DOCVIEWER_ENABLED=false)",
                    "error_code": "disabled",
                }

            if not self._ready:
                self.initialize()

            parsed, err = _parse_json_input(document)
            if err:
                return {
                    "success": False,
                    "agent": self.name,
                    "error": err,
                    "error_code": "validation",
                }

            available = known_tool_names()
            selected: list[str]
            if run_all:
                selected = list(available)
            elif tools:
                selected = [str(t).strip() for t in tools if str(t).strip()]
            else:
                selected = []

            tool_results: list[dict[str, Any]] = []
            unknown: list[str] = []
            for name in selected:
                handler = get_handler(name)
                if handler is None:
                    unknown.append(name)
                    tool_results.append(
                        {
                            "tool": name,
                            "status": "unknown",
                            "error": f"unknown tool: {name}",
                        }
                    )
                    continue
                try:
                    tool_results.append(handler(parsed))
                except Exception as exc:  # noqa: BLE001
                    logger.error("docviewer tool %s failed: %s", name, exc, exc_info=True)
                    tool_results.append(
                        {
                            "tool": name,
                            "status": "error",
                            "error": str(exc),
                        }
                    )

            return {
                "success": True,
                "agent": self.name,
                "mode": "docviewer_stub",
                "agents_used": [self.name],
                "input_type": type(parsed).__name__,
                "tools_available": available,
                "tools_requested": selected,
                "tools_unknown": unknown,
                "tool_results": tool_results,
                "document_echo": (
                    parsed if _env_bool("DOCVIEWER_ECHO_DOCUMENT", False) else None
                ),
                "message": (
                    "DocViewer accepted JSON. Tools are stubs until implemented."
                    if selected
                    else "DocViewer accepted JSON. No tools requested "
                    "(pass tools=[...] or run_all=true)."
                ),
                "timestamp": _now_iso(),
                "error": None,
            }
        except Exception as exc:  # noqa: BLE001
            logger.error("docviewer.process failed: %s", exc, exc_info=True)
            return {
                "success": False,
                "agent": self.name,
                "error": f"DocViewer error: {exc}",
                "error_code": "agent_error",
                "retryable": True,
            }


def get_docviewer_agent() -> DocViewerAgentService:
    global _service
    with _lock:
        if _service is None:
            _service = DocViewerAgentService()
            _service.initialize()
        elif not _service.ready and is_enabled():
            _service.initialize()
        return _service


# Re-export for API convenience
__all__ = [
    "DocViewerAgentService",
    "get_docviewer_agent",
    "is_enabled",
    "list_tools",
]
