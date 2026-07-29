"""
Knowledge Graph Builder Tool (DocViewer).

Stub — real graph building will be added later.
Input: parsed JSON document (dict | list | …).
"""

from __future__ import annotations

from typing import Any

NAME = "knowledge_graph_builder"

META: dict[str, Any] = {
    "name": NAME,
    "display_name": "Knowledge Graph Builder Tool",
    "description": (
        "Build a knowledge graph from the input JSON document. "
        "Stub only — implementation pending."
    ),
    "status": "stub",
}


def run(doc: Any) -> dict[str, Any]:
    """Primitive stub — no real graph yet."""
    return {
        "tool": NAME,
        "display_name": META["display_name"],
        "status": "stub",
        "message": (
            "Knowledge Graph Builder Tool is registered but not implemented yet."
        ),
        "preview": {
            "input_type": type(doc).__name__,
            "item_count": len(doc) if isinstance(doc, (list, dict)) else None,
        },
        "result": {
            "nodes": [],
            "edges": [],
            "note": "empty graph (stub)",
        },
    }
