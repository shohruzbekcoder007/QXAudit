"""
Neo4j Bolt client for QXAudit graph tools.

Env:
  NEO4J_ENABLED, NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD, NEO4J_DATABASE
"""

from __future__ import annotations

import logging
import os
import threading
from typing import Any, Optional

logger = logging.getLogger("neo4j_client")

_lock = threading.RLock()
_driver: Any = None


def _env(name: str, default: str = "") -> str:
    raw = os.getenv(name)
    return default if raw is None else raw.strip()


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def is_enabled() -> bool:
    return _env_bool("NEO4J_ENABLED", True)


def get_settings() -> dict[str, str]:
    return {
        "uri": _env("NEO4J_URI", "bolt://neo4j:7687"),
        "user": _env("NEO4J_USER", "neo4j"),
        "password": _env("NEO4J_PASSWORD", "qxaudit-neo4j-change-me"),
        "database": _env("NEO4J_DATABASE", "neo4j"),
    }


def get_driver() -> Any:
    """Lazy singleton driver. Raises if neo4j package missing or connect fails."""
    global _driver
    if not is_enabled():
        raise RuntimeError("NEO4J_ENABLED=false")
    with _lock:
        if _driver is not None:
            return _driver
        try:
            from neo4j import GraphDatabase  # type: ignore
        except ImportError as exc:
            raise RuntimeError(
                "neo4j package not installed (pip install neo4j)"
            ) from exc
        s = get_settings()
        _driver = GraphDatabase.driver(s["uri"], auth=(s["user"], s["password"]))
        # Verify connectivity early
        _driver.verify_connectivity()
        logger.info("Neo4j driver ready uri=%s db=%s", s["uri"], s["database"])
        return _driver


def close_driver() -> None:
    global _driver
    with _lock:
        if _driver is not None:
            try:
                _driver.close()
            except Exception:  # noqa: BLE001
                pass
            _driver = None


def run_cypher(
    query: str,
    parameters: dict[str, Any] | None = None,
    *,
    database: str | None = None,
) -> list[dict[str, Any]]:
    """
    Run a parameterized Cypher query. Returns list of records as dicts.
    Never pass user text into query string — only via parameters.
    """
    driver = get_driver()
    db = database or get_settings()["database"]
    params = parameters or {}
    with driver.session(database=db) as session:
        result = session.run(query, params)
        rows: list[dict[str, Any]] = []
        for record in result:
            row: dict[str, Any] = {}
            for key in record.keys():
                val = record[key]
                row[key] = _serialize(val)
            rows.append(row)
        return rows


def _serialize(val: Any) -> Any:
    """Make neo4j types JSON-friendly."""
    if val is None:
        return None
    if isinstance(val, (str, int, float, bool)):
        return val
    if isinstance(val, list):
        return [_serialize(v) for v in val]
    if isinstance(val, dict):
        return {str(k): _serialize(v) for k, v in val.items()}
    # Node / Relationship / Path / Date
    try:
        from neo4j.graph import Node, Relationship, Path  # type: ignore

        if isinstance(val, Node):
            return {
                "_type": "node",
                "labels": list(val.labels),
                "props": {k: _serialize(v) for k, v in dict(val).items()},
            }
        if isinstance(val, Relationship):
            return {
                "_type": "rel",
                "type": val.type,
                "props": {k: _serialize(v) for k, v in dict(val).items()},
            }
        if isinstance(val, Path):
            return {
                "_type": "path",
                "nodes": [_serialize(n) for n in val.nodes],
                "rels": [_serialize(r) for r in val.relationships],
            }
    except Exception:  # noqa: BLE001
        pass
    # Date / DateTime
    if hasattr(val, "iso_format"):
        try:
            return val.iso_format()
        except Exception:  # noqa: BLE001
            pass
    return str(val)


def readiness() -> dict[str, Any]:
    s = get_settings()
    out: dict[str, Any] = {
        "enabled": is_enabled(),
        "uri": s["uri"],
        "user": s["user"],
        "database": s["database"],
        "ready": False,
        "error": None,
    }
    if not is_enabled():
        out["error"] = "NEO4J_ENABLED=false"
        return out
    try:
        rows = run_cypher("RETURN 1 AS ok")
        out["ready"] = bool(rows and rows[0].get("ok") == 1)
        if out["ready"]:
            try:
                counts = run_cypher(
                    "MATCH (n) RETURN labels(n)[0] AS label, count(*) AS c "
                    "ORDER BY c DESC LIMIT 20"
                )
                out["labels"] = counts
            except Exception as exc:  # noqa: BLE001
                out["labels_error"] = str(exc)
    except Exception as exc:  # noqa: BLE001
        out["error"] = str(exc)
        logger.warning("Neo4j readiness failed: %s", exc)
    return out
