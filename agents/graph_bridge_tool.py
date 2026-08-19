"""
Bridge tool: QXAudit host → Neo4j knowledge graph (template Cypher).

Tool name: graph_ask
  User/host never send raw Cypher — only intent + anchor fields.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Callable, Optional

logger = logging.getLogger("graph_bridge")

TOOLSET_NAME = "graph_bridge"
TOOL_NAME = "graph_ask"

TOOL_SCHEMA: dict[str, Any] = {
    "name": TOOL_NAME,
    "description": (
        "Query the YaICh knowledge graph in Neo4j (indicators, formulas, "
        "paragraphs/bands, calculation chains, data sources). "
        "Use for formula, hisoblash, ko'rsatkich, band raqami, manba, "
        "deflyator, FHI, 2026 raqamlar. Do NOT invent Cypher — pass intent "
        "and name/code/number. For free-text document wording use docs_ask."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "question": {
                "type": "string",
                "description": "User question (used for auto intent and search)",
            },
            "intent": {
                "type": "string",
                "description": (
                    "One of: auto, indicator_formula, indicator_definition, "
                    "paragraph, calc_chain, sources, search. Default auto."
                ),
            },
            "name": {
                "type": "string",
                "description": "Indicator or source name fragment, e.g. 'Don ekinlari'",
            },
            "code": {
                "type": "string",
                "description": "Exact node code if known, e.g. IND_… or source code",
            },
            "number": {
                "type": "integer",
                "description": "Paragraph/band number for intent=paragraph",
            },
        },
        "required": [],
    },
}


def graph_ask_handler(args: dict[str, Any] | None = None, **kwargs: Any) -> str:
    """Hermes / host tool handler — never raises."""
    del kwargs
    args = args or {}
    try:
        from tools.graph.service import format_for_host, graph_ask

        question = str(
            args.get("question")
            or args.get("query")
            or args.get("message")
            or ""
        ).strip()
        intent = str(args.get("intent") or "auto").strip() or "auto"
        name = str(args.get("name") or "").strip()
        code = str(args.get("code") or "").strip()
        number: Optional[int] = None
        raw_num = args.get("number")
        if raw_num is not None and str(raw_num).strip() != "":
            try:
                number = int(raw_num)
            except (TypeError, ValueError):
                number = None

        if not question and not name and not code and number is None:
            return json.dumps(
                {
                    "success": False,
                    "error": "Provide question and/or name/code/number",
                },
                ensure_ascii=False,
            )

        result = graph_ask(
            question=question,
            intent=intent,
            name=name,
            code=code,
            number=number,
        )
        # Host-friendly plain text + compact JSON for structure
        text = format_for_host(result)
        payload = {
            "success": result.get("success"),
            "intent": result.get("intent"),
            "cypher_name": result.get("cypher_name"),
            "row_count": result.get("row_count"),
            "text": text,
            "rows": result.get("rows"),
            "candidates": result.get("candidates"),
            "error": result.get("error"),
            "error_code": result.get("error_code"),
        }
        return text + "\n\n" + json.dumps(payload, ensure_ascii=False, default=str)
    except Exception as exc:  # noqa: BLE001
        logger.error("graph_ask_handler failed: %s", exc, exc_info=True)
        return json.dumps(
            {"success": False, "error": f"graph_ask failed: {exc}"},
            ensure_ascii=False,
        )


def get_tool_handlers() -> dict[str, Callable[..., str]]:
    return {TOOL_NAME: graph_ask_handler}


def register_hermes_tools() -> list[str]:
    try:
        from tools.registry import registry  # type: ignore[import-not-found]
    except Exception as exc:  # noqa: BLE001
        logger.debug("Hermes registry not available: %s", exc)
        return []
    try:
        registry.register(
            name=TOOL_NAME,
            toolset=TOOLSET_NAME,
            schema=TOOL_SCHEMA,
            handler=graph_ask_handler,
            description=TOOL_SCHEMA["description"],
        )
        logger.info("Registered Hermes tool %s (toolset=%s)", TOOL_NAME, TOOLSET_NAME)
        return [TOOL_NAME]
    except Exception as exc:  # noqa: BLE001
        logger.warning("Hermes registry.register failed for graph_ask: %s", exc)
        return []


def as_langchain_tool():
    from langchain_core.tools import StructuredTool
    from pydantic import BaseModel, Field

    class GraphAskInput(BaseModel):
        question: str = Field(
            default="",
            description="User question (auto intent / search text)",
        )
        intent: str = Field(
            default="auto",
            description=(
                "auto | indicator_formula | indicator_definition | paragraph | "
                "calc_chain | sources | search"
            ),
        )
        name: str = Field(default="", description="Indicator/source name fragment")
        code: str = Field(default="", description="Exact node code if known")
        number: Optional[int] = Field(
            default=None, description="Band/paragraph number"
        )

    def _run(
        question: str = "",
        intent: str = "auto",
        name: str = "",
        code: str = "",
        number: Optional[int] = None,
    ) -> str:
        return graph_ask_handler(
            {
                "question": question,
                "intent": intent,
                "name": name,
                "code": code,
                "number": number,
            }
        )

    return StructuredTool.from_function(
        name=TOOL_NAME,
        description=TOOL_SCHEMA["description"],
        func=_run,
        args_schema=GraphAskInput,
    )
