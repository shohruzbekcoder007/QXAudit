"""
Single source of truth for which LLM backend the app talks to.

Both provider configs live side by side in .env; switching is one line:

    LLM_PROVIDER=openai   → api.openai.com (OPENAI_* / LLM_MODEL vars)
    LLM_PROVIDER=ollama   → local Ollama OpenAI-compatible endpoint (OLLAMA_*)

Any OpenAI-compatible server (vLLM, LM Studio) also works through the ollama
branch — point OLLAMA_BASE_URL at it and name the model it serves.

Used by: hermes_host (host agent + meta tasks) and rag_agent (_generate_answer).
Embeddings are configured separately (RAG_EMBED_* in agents/embeddings.py).
"""

from __future__ import annotations

import os
from typing import Any, Optional


def _env(name: str, default: str = "") -> str:
    raw = os.getenv(name)
    return default if raw is None else raw.strip()


def get_provider() -> str:
    """openai (default) | ollama."""
    raw = _env("LLM_PROVIDER", "openai").lower()
    return raw if raw in {"openai", "ollama"} else "openai"


def get_llm_settings() -> dict[str, Any]:
    """
    Resolve (provider, model, task_model, api_key, base_url) from env.

    HERMES_MODEL / RAG_LLM_MODEL overrides are applied by the callers on top
    of `model`, so they keep working with either provider.
    """
    provider = get_provider()

    if provider == "ollama":
        base_url = (
            _env("OLLAMA_BASE_URL") or "http://host.docker.internal:11434/v1"
        )
        model = _env("OLLAMA_MODEL") or "qwen3:8b"
        return {
            "provider": "ollama",
            "model": model,
            # Ollama has no per-token pricing; default the housekeeping tasks
            # to the same local model unless a smaller one is named.
            "task_model": _env("OLLAMA_TASK_MODEL") or model,
            # Ollama ignores the key but the OpenAI client requires a non-empty
            # string; never falls back to the real OpenAI key.
            "api_key": _env("OLLAMA_API_KEY") or "ollama",
            "base_url": base_url,
        }

    # openai (default)
    return {
        "provider": "openai",
        "model": _env("LLM_MODEL") or _env("OPENAI_MODEL") or "gpt-4.1",
        "task_model": _env("HERMES_TASK_MODEL") or "gpt-4.1-mini",
        "api_key": (
            _env("OPENAI_API_KEY") or _env("LLM_API_KEY") or _env("HERMES_API_KEY")
        ),
        "base_url": _env("OPENAI_BASE_URL") or None,
    }


def describe() -> dict[str, Any]:
    """Readiness-friendly view (no secrets)."""
    s = get_llm_settings()
    return {
        "provider": s["provider"],
        "model": s["model"],
        "task_model": s["task_model"],
        "base_url": s["base_url"],
        "api_key_set": bool(s["api_key"]),
    }
