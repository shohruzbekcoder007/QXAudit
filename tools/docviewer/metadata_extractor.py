"""
Metadata Extractor Tool (DocViewer).

Stub — real extraction logic will be added later.
Input: parsed JSON document (dict | list | …).
"""

from __future__ import annotations

from typing import Any

NAME = "metadata_extractor"

META: dict[str, Any] = {
    "name": NAME,
    "display_name": "Metadata Extractor Tool",
    "description": (
        "Extract metadata from the input JSON document. "
        "Stub only — implementation pending."
    ),
    "status": "stub",
}


def run(doc: Any) -> dict[str, Any]:
    """Primitive stub — no real extraction yet."""
    keys: list[str] = []
    if isinstance(doc, dict):
        keys = list(doc.keys())[:50]
    return {
        "tool": NAME,
        "display_name": META["display_name"],
        "status": "stub",
        "message": "Metadata Extractor Tool is registered but not implemented yet.",
        "preview": {
            "input_type": type(doc).__name__,
            "top_level_keys": keys if keys else None,
            "item_count": len(doc) if isinstance(doc, (list, dict)) else None,
        },
        "result": None,
    }
