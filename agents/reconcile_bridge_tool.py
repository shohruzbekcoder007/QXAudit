"""
Bridge tool: QXAudit host → deterministic reconciliation checks.

Tool name: reconcile_check
  The model never computes a figure: it picks which checks to run and relays
  the verdicts this tool returns.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Callable, Optional

logger = logging.getLogger("reconcile_bridge")

TOOLSET_NAME = "graph_bridge"
TOOL_NAME = "reconcile_check"

TOOL_SCHEMA: dict[str, Any] = {
    "name": TOOL_NAME,
    "description": (
        "Verify the YaICh figures against the methodology identities: aggregate "
        "sums (24, 26, 30-band), FHI x deflator = nominal change, region and "
        "producer-category totals, and the 'Respublika' vs 'valovka' variance. "
        "Use when the user asks whether numbers are correct, add up, reconcile, "
        "or before a quarterly figure is presented. All arithmetic happens in "
        "this tool — never compute or estimate a figure yourself."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "checks": {
                "type": "array",
                "items": {"type": "string"},
                "description": (
                    "Which checks to run: aggregate_sums, fhi_deflator_identity, "
                    "valovka_variance, region_sum, category_sum. Omit to run all."
                ),
            },
            "tolerance_mlrd": {
                "type": "number",
                "description": "Allowed rounding difference in mlrd so'm (default 0.5)",
            },
            "tolerance_percent": {
                "type": "number",
                "description": "Allowed difference for percent identities (default 0.2)",
            },
            "period": {
                "type": "string",
                "description": "Period code, e.g. P_2026_H1. Omit for all periods.",
            },
        },
        "required": [],
    },
}


def reconcile_check_handler(args: dict[str, Any] | None = None, **kwargs: Any) -> str:
    """Host tool handler — never raises."""
    del kwargs
    args = args or {}
    try:
        from tools.graph.reconcile import format_for_host, reconcile_check

        raw_checks = args.get("checks")
        checks: Optional[list[str]] = None
        if isinstance(raw_checks, str):
            checks = [c.strip() for c in raw_checks.split(",") if c.strip()]
        elif isinstance(raw_checks, (list, tuple)):
            checks = [str(c).strip() for c in raw_checks if str(c).strip()]
        if not checks:
            checks = None

        def _f(name: str, default: float) -> float:
            val = args.get(name)
            if val is None or str(val).strip() == "":
                return default
            try:
                return float(val)
            except (TypeError, ValueError):
                return default

        result = reconcile_check(
            checks=checks,
            tolerance_mlrd=_f("tolerance_mlrd", 0.5),
            tolerance_percent=_f("tolerance_percent", 0.2),
            period=str(args.get("period") or "").strip(),
        )
        text = format_for_host(result)
        payload = {
            "success": result.get("success"),
            "summary": result.get("summary"),
            "checks_run": result.get("checks_run"),
            "text": text,
            "results": result.get("results"),
            "error": result.get("error"),
            "error_code": result.get("error_code"),
        }
        return text + "\n\n" + json.dumps(payload, ensure_ascii=False, default=str)
    except Exception as exc:  # noqa: BLE001
        logger.error("reconcile_check_handler failed: %s", exc, exc_info=True)
        return json.dumps(
            {"success": False, "error": f"reconcile_check failed: {exc}"},
            ensure_ascii=False,
        )


def get_tool_handlers() -> dict[str, Callable[..., str]]:
    return {TOOL_NAME: reconcile_check_handler}


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
            handler=reconcile_check_handler,
            description=TOOL_SCHEMA["description"],
        )
        logger.info("Registered Hermes tool %s (toolset=%s)", TOOL_NAME, TOOLSET_NAME)
        return [TOOL_NAME]
    except Exception as exc:  # noqa: BLE001
        logger.warning("Hermes registry.register failed for %s: %s", TOOL_NAME, exc)
        return []


def as_langchain_tool():
    from langchain_core.tools import StructuredTool
    from pydantic import BaseModel, Field

    class ReconcileInput(BaseModel):
        checks: list[str] = Field(
            default_factory=list,
            description=(
                "aggregate_sums | fhi_deflator_identity | valovka_variance | "
                "region_sum | category_sum. Empty = all."
            ),
        )
        tolerance_mlrd: float = Field(
            default=0.5, description="Rounding tolerance in mlrd so'm"
        )
        tolerance_percent: float = Field(
            default=0.2, description="Tolerance for percent identities"
        )
        period: str = Field(default="", description="Period code, e.g. P_2026_H1")

    def _run(
        checks: Optional[list[str]] = None,
        tolerance_mlrd: float = 0.5,
        tolerance_percent: float = 0.2,
        period: str = "",
    ) -> str:
        return reconcile_check_handler(
            {
                "checks": checks or [],
                "tolerance_mlrd": tolerance_mlrd,
                "tolerance_percent": tolerance_percent,
                "period": period,
            }
        )

    return StructuredTool.from_function(
        name=TOOL_NAME,
        description=TOOL_SCHEMA["description"],
        func=_run,
        args_schema=ReconcileInput,
    )
