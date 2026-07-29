"""
DocViewer tools — one module per tool (project-level ``tools/docviewer/``).

Add a new tool:
  1. Create tools/docviewer/<name>.py with NAME, META, run(doc)
  2. Import and register it in TOOL_MODULES below
"""

from __future__ import annotations

from typing import Any, Callable

from tools.docviewer import knowledge_graph_builder, metadata_extractor

# Registration order = default run_all order
TOOL_MODULES = (
    metadata_extractor,
    knowledge_graph_builder,
)

TOOL_REGISTRY: dict[str, dict[str, Any]] = {}
_TOOL_HANDLERS: dict[str, Callable[[Any], dict[str, Any]]] = {}

for _mod in TOOL_MODULES:
    _meta = dict(_mod.META)
    _name = str(_meta["name"])
    TOOL_REGISTRY[_name] = _meta
    _TOOL_HANDLERS[_name] = _mod.run

TOOL_METADATA_EXTRACTOR = metadata_extractor.NAME
TOOL_KNOWLEDGE_GRAPH_BUILDER = knowledge_graph_builder.NAME


def list_tools() -> list[dict[str, Any]]:
    return [dict(v) for v in TOOL_REGISTRY.values()]


def get_handler(name: str) -> Callable[[Any], dict[str, Any]] | None:
    return _TOOL_HANDLERS.get(name)


def known_tool_names() -> list[str]:
    return list(TOOL_REGISTRY.keys())


__all__ = [
    "TOOL_REGISTRY",
    "TOOL_METADATA_EXTRACTOR",
    "TOOL_KNOWLEDGE_GRAPH_BUILDER",
    "list_tools",
    "get_handler",
    "known_tool_names",
]
