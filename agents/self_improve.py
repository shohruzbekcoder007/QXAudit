"""
Global self-improving layer for QXAudit (host + RAG).

Successful question → answer pairs are stored as reusable "recipes".
On a new question, top-k similar recipes are injected as few-shot hints
into the host system prompt (bounded — no unbounded prompt growth).

Design:
* GLOBAL store shared by all sessions on this instance
* Leak-safe: stores short Q/A text only (no raw DB rows / full docs)
* Lexical retrieval (no embedding dependency)
* Best-effort: failures never break chat
"""

from __future__ import annotations

import json
import logging
import os
import re
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

logger = logging.getLogger("self_improve")

_lock = threading.RLock()
_store: Optional["RecipeStore"] = None


def _env(name: str, default: str = "") -> str:
    raw = os.getenv(name)
    return default if raw is None else raw.strip()


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


def _env_float(name: str, default: float) -> float:
    raw = os.getenv(name)
    if raw is None or not str(raw).strip():
        return default
    try:
        return float(raw)
    except ValueError:
        return default


def is_enabled() -> bool:
    return _env_bool("SELF_IMPROVE_ENABLED", True)


def _store_path() -> Path:
    raw = _env("SELF_IMPROVE_STORE_PATH")
    if raw:
        return Path(raw)
    return Path(__file__).resolve().parent.parent / "data" / "self_improve.json"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


_TOKEN_RE = re.compile(r"[\w\u0400-\u04FF\u0500-\u052F]+", re.UNICODE)


def _tokens(text: str) -> set[str]:
    return {t.lower() for t in _TOKEN_RE.findall(text or "") if len(t) > 1}


def _similarity(a: str, b: str) -> float:
    ta, tb = _tokens(a), _tokens(b)
    if not ta or not tb:
        return 0.0
    inter = len(ta & tb)
    union = len(ta | tb)
    return inter / union if union else 0.0


def _clip(text: str, n: int) -> str:
    t = (text or "").strip()
    if len(t) <= n:
        return t
    return t[: n - 1] + "…"


class RecipeStore:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or _store_path()
        self.max_recipes = _env_int("SELF_IMPROVE_MAX_RECIPES", 500)
        self.recipes: list[dict[str, Any]] = []
        self._load()

    def _load(self) -> None:
        if not self.path.is_file():
            self.recipes = []
            return
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                recipes = data.get("recipes")
            elif isinstance(data, list):
                recipes = data
            else:
                recipes = []
            self.recipes = [r for r in (recipes or []) if isinstance(r, dict)]
            logger.info(
                "self_improve store loaded: %d recipes from %s",
                len(self.recipes),
                self.path,
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("self_improve load failed (%s): %s", self.path, exc)
            self.recipes = []

    def _save(self) -> None:
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            payload = {
                "version": 1,
                "updated_at": _now_iso(),
                "recipes": self.recipes,
            }
            tmp = self.path.with_suffix(".tmp")
            tmp.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            os.replace(tmp, self.path)
        except Exception as exc:  # noqa: BLE001
            logger.warning("self_improve save failed (%s): %s", self.path, exc)

    def stats(self) -> dict[str, Any]:
        return {
            "enabled": is_enabled(),
            "path": str(self.path),
            "count": len(self.recipes),
            "max_recipes": self.max_recipes,
            "top_k": _env_int("SELF_IMPROVE_TOP_K", 3),
            "min_score": _env_float("SELF_IMPROVE_MIN_SCORE", 0.18),
        }

    def learn(
        self,
        question: str,
        answer: str,
        *,
        mode: str | None = None,
        agents_used: list[str] | None = None,
    ) -> bool:
        q = (question or "").strip()
        a = (answer or "").strip()
        if len(q) < 4 or len(a) < 8:
            return False
        # Skip obvious failures / empty / error-ish answers
        low = a.lower()
        if any(
            x in low
            for x in (
                "not ready",
                "error",
                "xato",
                "failed",
                "disabled",
                "empty_index",
            )
        ):
            return False

        with _lock:
            # Merge into most similar existing recipe if very close
            best_i, best_s = -1, 0.0
            for i, r in enumerate(self.recipes):
                s = _similarity(q, str(r.get("question") or ""))
                if s > best_s:
                    best_s, best_i = s, i
            if best_i >= 0 and best_s >= 0.92:
                r = self.recipes[best_i]
                r["answer"] = _clip(a, 1200)
                r["use_count"] = int(r.get("use_count") or 0) + 1
                r["updated_at"] = _now_iso()
                if mode:
                    r["mode"] = mode
                if agents_used:
                    r["agents_used"] = agents_used
                self._save()
                return True

            recipe = {
                "id": f"r{len(self.recipes)+1:05d}",
                "question": _clip(q, 500),
                "answer": _clip(a, 1200),
                "mode": mode or "chat",
                "agents_used": agents_used or [],
                "use_count": 1,
                "created_at": _now_iso(),
                "updated_at": _now_iso(),
            }
            self.recipes.append(recipe)
            self._prune()
            self._save()
            logger.info(
                "self_improve: learned recipe (total=%d) q=%r",
                len(self.recipes),
                recipe["question"][:80],
            )
            return True

    def _prune(self) -> None:
        over = len(self.recipes) - self.max_recipes
        if over <= 0:
            return
        # Drop least-used, oldest first among ties
        ranked = sorted(
            range(len(self.recipes)),
            key=lambda i: (
                int(self.recipes[i].get("use_count") or 0),
                str(self.recipes[i].get("updated_at") or ""),
            ),
        )
        drop = set(ranked[:over])
        self.recipes = [r for i, r in enumerate(self.recipes) if i not in drop]
        logger.info("self_improve: pruned %d low-use recipes", over)

    def retrieve(self, question: str) -> list[dict[str, Any]]:
        q = (question or "").strip()
        if not q or not self.recipes:
            return []
        top_k = _env_int("SELF_IMPROVE_TOP_K", 3)
        min_score = _env_float("SELF_IMPROVE_MIN_SCORE", 0.18)
        scored: list[tuple[float, dict[str, Any]]] = []
        for r in self.recipes:
            s = _similarity(q, str(r.get("question") or ""))
            if s >= min_score:
                scored.append((s, r))
        scored.sort(key=lambda x: (-x[0], -int(x[1].get("use_count") or 0)))
        out: list[dict[str, Any]] = []
        for s, r in scored[:top_k]:
            item = dict(r)
            item["score"] = round(s, 4)
            out.append(item)
            r["use_count"] = int(r.get("use_count") or 0) + 1
        if out:
            try:
                self._save()
            except Exception:  # noqa: BLE001
                pass
        return out


def get_store() -> RecipeStore:
    global _store
    with _lock:
        if _store is None:
            _store = RecipeStore()
        return _store


def stats() -> dict[str, Any]:
    try:
        return get_store().stats()
    except Exception as exc:  # noqa: BLE001
        return {"enabled": is_enabled(), "error": str(exc)}


def retrieve_recipes(question: str) -> list[dict[str, Any]]:
    if not is_enabled():
        return []
    try:
        return get_store().retrieve(question)
    except Exception as exc:  # noqa: BLE001
        logger.debug("self_improve retrieve skipped: %s", exc)
        return []


def learn_from_result(
    question: str,
    result: dict[str, Any],
) -> None:
    """Learn from a successful host/RAG chat result dict."""
    if not is_enabled():
        return
    try:
        if not result or not result.get("success"):
            return
        answer = result.get("response")
        if not answer:
            return
        get_store().learn(
            question,
            str(answer),
            mode=str(result.get("mode") or "chat"),
            agents_used=list(result.get("agents_used") or []),
        )
    except Exception as exc:  # noqa: BLE001
        logger.debug("self_improve learn skipped: %s", exc)


def format_few_shot_block(recipes: list[dict[str, Any]]) -> str:
    if not recipes:
        return ""
    lines = [
        "",
        "## Learned patterns (self-improve — use only if relevant; still call tools for facts)",
    ]
    for i, r in enumerate(recipes, 1):
        lines.append(f"### Example {i} (score={r.get('score')})")
        lines.append(f"Q: {r.get('question')}")
        lines.append(f"A: {r.get('answer')}")
        lines.append("")
    return "\n".join(lines)


def augment_system_prompt(system_prompt: str, question: str) -> str:
    """Append retrieved recipes to the host system prompt."""
    if not is_enabled():
        return system_prompt
    try:
        recipes = retrieve_recipes(question)
        block = format_few_shot_block(recipes)
        if not block:
            return system_prompt
        return (system_prompt or "").rstrip() + "\n" + block
    except Exception as exc:  # noqa: BLE001
        logger.debug("self_improve augment skipped: %s", exc)
        return system_prompt
