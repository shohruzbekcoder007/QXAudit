"""
Parameterized Cypher templates for YaICh ontology.

Flow:
  user text / host args → intent + anchor → fixed Cypher + $params → Neo4j
"""

from __future__ import annotations

import logging
import re
from typing import Any, Optional

logger = logging.getLogger("graph_service")

INTENTS = (
    "auto",
    "indicator_formula",
    "indicator_definition",
    "paragraph",
    "calc_chain",
    "sources",
    "search",
)

_BAND_RE = re.compile(
    r"(?i)(?:^|\s)(\d{1,3})\s*[-–—.]?\s*(?:band|§|bandi)\b|"
    r"(?:band|§)\s*(\d{1,3})\b"
)


def list_intents() -> list[dict[str, str]]:
    return [
        {
            "name": "auto",
            "description": "Savoldan intent va anchor ni avtomatik aniqlash",
        },
        {
            "name": "indicator_formula",
            "description": "Ko'rsatkich → USES_FORMULA → Formula",
        },
        {
            "name": "indicator_definition",
            "description": "Ko'rsatkich → DEFINED_IN → Paragraph (band)",
        },
        {
            "name": "paragraph",
            "description": "Band raqami bo'yicha Paragraph matni",
        },
        {
            "name": "calc_chain",
            "description": "Indicator CALCULATED_FROM zanjiri",
        },
        {
            "name": "sources",
            "description": "Manba / hisobot / tashkilot zanjiri",
        },
        {
            "name": "search",
            "description": "Fulltext yoki CONTAINS bo'yicha kandidat qidiruv",
        },
    ]


def _extract_band(text: str) -> Optional[int]:
    m = _BAND_RE.search(text or "")
    if not m:
        return None
    for g in m.groups():
        if g:
            try:
                return int(g)
            except ValueError:
                continue
    return None


def _guess_intent(question: str, *, name: str, code: str, number: Optional[int]) -> str:
    q = (question or "").lower()
    if number is not None or _extract_band(question):
        if any(k in q for k in ("formula", "hisob", "qanday hisob")):
            pass  # may still be formula about a band
        else:
            return "paragraph"
    if any(
        k in q
        for k in (
            "formula",
            "formul",
            "hisoblan",
            "qanday hisob",
            "hisoblash",
        )
    ):
        return "indicator_formula"
    if any(k in q for k in ("yig'ind", "yigind", "tashkil top", "calculated", "zanjir", "qism")):
        return "calc_chain"
    if any(
        k in q
        for k in (
            "manba",
            "4fx",
            "4dx",
            "4qx",
            "hisobot",
            "source",
            "tashkilot",
        )
    ):
        return "sources"
    if any(k in q for k in ("aniqlan", "ta'rif", "tarif", "defined", "qaysi band")):
        return "indicator_definition"
    if name or code:
        return "indicator_formula"
    return "search"


def graph_ask(
    *,
    question: str = "",
    intent: str = "auto",
    name: str = "",
    code: str = "",
    number: Optional[int] = None,
    limit: int = 10,
) -> dict[str, Any]:
    """
    Resolve intent/anchor and run a template query.
    Never raises to callers — errors in result dict.
    """
    from agents.neo4j_client import is_enabled, readiness, run_cypher

    question = (question or "").strip()
    name = (name or "").strip()
    code = (code or "").strip()
    intent = (intent or "auto").strip().lower()
    if number is None:
        number = _extract_band(question)

    if not is_enabled():
        return {
            "success": False,
            "error": "Neo4j disabled (NEO4J_ENABLED=false)",
            "error_code": "disabled",
        }

    if intent not in INTENTS:
        return {
            "success": False,
            "error": f"unknown intent: {intent}; allowed={list(INTENTS)}",
            "error_code": "validation",
        }

    if intent == "auto":
        intent = _guess_intent(question, name=name, code=code, number=number)

    # If only free text and no name/code, try to use whole question as search name snippet
    if not name and not code and question and intent in {
        "indicator_formula",
        "indicator_definition",
        "calc_chain",
        "sources",
    }:
        # Strip common question tails for name-ish search
        name = re.sub(
            r"(?i)\s*(qanday|qanday\s+formula|bilan|hisoblanadi|nima|qaysi).*$",
            "",
            question,
        ).strip(" ?!.,")
        if len(name) < 3:
            name = question[:80]

    try:
        if intent == "paragraph":
            return _run_paragraph(run_cypher, number=number, question=question, limit=limit)
        if intent == "indicator_formula":
            return _run_indicator_formula(
                run_cypher, name=name, code=code, question=question, limit=limit
            )
        if intent == "indicator_definition":
            return _run_indicator_definition(
                run_cypher, name=name, code=code, question=question, limit=limit
            )
        if intent == "calc_chain":
            return _run_calc_chain(
                run_cypher, name=name, code=code, question=question, limit=limit
            )
        if intent == "sources":
            return _run_sources(
                run_cypher, name=name, code=code, question=question, limit=limit
            )
        # search
        return _run_search(run_cypher, question=question or name, limit=limit)
    except Exception as exc:  # noqa: BLE001
        logger.error("graph_ask failed: %s", exc, exc_info=True)
        rd = readiness()
        return {
            "success": False,
            "error": str(exc),
            "error_code": "neo4j_error",
            "intent": intent,
            "neo4j": {"ready": rd.get("ready"), "error": rd.get("error")},
        }


def _run_paragraph(run_cypher, *, number: Optional[int], question: str, limit: int) -> dict[str, Any]:
    if number is None:
        return {
            "success": False,
            "error": "paragraph intent needs band number (e.g. '80-band') or number=",
            "error_code": "validation",
            "intent": "paragraph",
            "hint": "Pass number=80 or ask '80-bandda nima yozilgan?'",
        }
    cypher = """
    MATCH (p:Paragraph)
    WHERE p.number = $number OR toString(p.number) = toString($number)
    OPTIONAL MATCH (p)-[:BELONGS_TO]->(m:Methodology)
    RETURN p.number AS number, p.title AS title, p.text AS text,
           p.chapter AS chapter, p.chapter_title AS chapter_title,
           m.name AS methodology
    LIMIT $limit
    """
    rows = run_cypher(cypher, {"number": number, "limit": limit})
    return _ok("paragraph", cypher_name="paragraph_by_number", params={"number": number}, rows=rows)


def _resolve_indicators(run_cypher, *, name: str, code: str, limit: int) -> list[dict[str, Any]]:
    cypher = """
    MATCH (i:Indicator)
    WHERE ($code <> '' AND i.code = $code)
       OR ($name <> '' AND (
            toLower(coalesce(i.name, '')) CONTAINS toLower($name)
         OR toLower(coalesce(i.izoh, '')) CONTAINS toLower($name)
         OR toLower(coalesce(i.code, '')) CONTAINS toLower($name)
       ))
    RETURN i.code AS code, i.name AS name,
           i.qiymat_2026_mlrd_som AS qiymat_2026,
           i.osish_foiz AS osish_foiz,
           i.deflyator_foiz AS deflyator_foiz
    LIMIT $limit
    """
    return run_cypher(
        cypher,
        {"name": name or "", "code": code or "", "limit": max(1, min(limit, 20))},
    )


def _pick_indicator(
    candidates: list[dict[str, Any]],
    *,
    intent: str,
    name: str,
    code: str,
) -> tuple[Optional[dict[str, Any]], Optional[dict[str, Any]]]:
    """
    Choose exactly one indicator, or refuse and ask the user.

    Never silently takes candidates[0]: a wrong pick returns a plausible but
    wrong number, which the user cannot detect.

    Returns (picked, ambiguous_result) — exactly one of the two is not None.
    """
    if code:
        for c in candidates:
            if str(c.get("code") or "") == code:
                return c, None
    if len(candidates) == 1:
        return candidates[0], None

    # Exact name match wins over substring matches ("Sut" vs "Sut mahsulotlari")
    wanted = (name or "").strip().lower()
    if wanted:
        exact = [
            c for c in candidates
            if str(c.get("name") or "").strip().lower() == wanted
        ]
        if len(exact) == 1:
            return exact[0], None

    return None, {
        "success": False,
        "error": (
            f"{len(candidates)} ta ko'rsatkich mos keldi — qaysi biri kerakligini "
            "foydalanuvchidan so'rang (o'zingiz tanlamang)."
        ),
        "error_code": "ambiguous",
        "intent": intent,
        "candidates": candidates,
        "rows": [],
        "agent": "QXAudit.graph",
    }


def _run_indicator_formula(
    run_cypher, *, name: str, code: str, question: str, limit: int
) -> dict[str, Any]:
    if not name and not code:
        return {
            "success": False,
            "error": "indicator_formula needs name= or code=",
            "error_code": "validation",
            "intent": "indicator_formula",
        }
    # Resolve candidates first if no exact code
    candidates = _resolve_indicators(run_cypher, name=name, code=code, limit=limit)
    if not candidates:
        return {
            "success": False,
            "error": f"Indicator topilmadi (name={name!r} code={code!r})",
            "error_code": "not_found",
            "intent": "indicator_formula",
            "rows": [],
        }
    pick, ambiguous = _pick_indicator(
        candidates, intent="indicator_formula", name=name, code=code
    )
    if ambiguous is not None:
        return ambiguous
    use_code = str((pick or {}).get("code") or "")

    cypher = """
    MATCH (i:Indicator {code: $code})
    OPTIONAL MATCH (i)-[:USES_FORMULA]->(f:Formula)
    OPTIONAL MATCH (i)-[:DEFINED_IN]->(p:Paragraph)
    OPTIONAL MATCH (i)-[:MEASURED_IN]->(u:Unit)
    RETURN i.code AS code, i.name AS name,
           i.qiymat_2026_mlrd_som AS qiymat_2026,
           i.hajm_2026 AS hajm_2026,
           i.osish_foiz AS osish_foiz,
           i.deflyator_foiz AS deflyator_foiz,
           f.code AS formula_code,
           coalesce(f.ifoda, f.name) AS formula,
           f.mazmun AS formula_mazmun,
           f.turi AS formula_turi,
           p.number AS band, p.title AS band_title,
           u.name AS unit
    LIMIT $limit
    """
    rows = run_cypher(cypher, {"code": use_code, "limit": limit})
    return _ok(
        "indicator_formula",
        cypher_name="indicator_uses_formula",
        params={"code": use_code, "name": name},
        rows=rows,
    )


def _run_indicator_definition(
    run_cypher, *, name: str, code: str, question: str, limit: int
) -> dict[str, Any]:
    if not name and not code:
        return {
            "success": False,
            "error": "indicator_definition needs name= or code=",
            "error_code": "validation",
            "intent": "indicator_definition",
        }
    candidates = _resolve_indicators(run_cypher, name=name, code=code, limit=limit)
    if not candidates:
        return {
            "success": False,
            "error": f"Indicator topilmadi (name={name!r} code={code!r})",
            "error_code": "not_found",
            "intent": "indicator_definition",
        }
    pick, ambiguous = _pick_indicator(
        candidates, intent="indicator_definition", name=name, code=code
    )
    if ambiguous is not None:
        return ambiguous
    use_code = str((pick or {}).get("code") or code)
    cypher = """
    MATCH (i:Indicator {code: $code})-[:DEFINED_IN]->(p:Paragraph)
    OPTIONAL MATCH (p)-[:BELONGS_TO]->(m:Methodology)
    RETURN i.code AS code, i.name AS name,
           p.number AS band, p.title AS title, p.text AS text,
           p.chapter AS chapter, m.name AS methodology
    LIMIT $limit
    """
    rows = run_cypher(cypher, {"code": use_code, "limit": limit})
    return _ok(
        "indicator_definition",
        cypher_name="indicator_defined_in",
        params={"code": use_code},
        rows=rows,
    )


def _run_calc_chain(
    run_cypher, *, name: str, code: str, question: str, limit: int
) -> dict[str, Any]:
    if not name and not code:
        return {
            "success": False,
            "error": "calc_chain needs name= or code=",
            "error_code": "validation",
            "intent": "calc_chain",
        }
    candidates = _resolve_indicators(run_cypher, name=name, code=code, limit=5)
    if not candidates:
        return {
            "success": False,
            "error": f"Indicator topilmadi (name={name!r} code={code!r})",
            "error_code": "not_found",
            "intent": "calc_chain",
        }
    pick, ambiguous = _pick_indicator(
        candidates, intent="calc_chain", name=name, code=code
    )
    if ambiguous is not None:
        return ambiguous
    use_code = str((pick or {}).get("code") or code)
    cypher = """
    MATCH (i:Indicator {code: $code})
    OPTIONAL MATCH (i)-[:CALCULATED_FROM]->(part:Indicator)
    RETURN i.code AS parent_code, i.name AS parent_name,
           i.qiymat_2026_mlrd_som AS parent_qiymat,
           collect({
             code: part.code,
             name: part.name,
             qiymat_2026: part.qiymat_2026_mlrd_som
           }) AS parts
    LIMIT 1
    """
    rows = run_cypher(cypher, {"code": use_code})
    return _ok(
        "calc_chain",
        cypher_name="indicator_calculated_from",
        params={"code": use_code},
        rows=rows,
    )


def _run_sources(
    run_cypher, *, name: str, code: str, question: str, limit: int
) -> dict[str, Any]:
    q = name or question or code
    # Form codes are written with a space in the graph ("4 dx") but users type
    # "4dx" — compare with spaces removed on both sides.
    cypher = """
    MATCH (s:Source)
    WHERE ($q <> '' AND (
         toLower(coalesce(s.name, '')) CONTAINS toLower($q)
      OR toLower(coalesce(s.code, '')) CONTAINS toLower($q)
      OR toLower(coalesce(s.qamrov, '')) CONTAINS toLower($q)
      OR replace(toLower(coalesce(s.shakl, '')), ' ', '')
         CONTAINS replace(toLower($q), ' ', '')
    )) OR ($code <> '' AND s.code = $code)
    OPTIONAL MATCH (s)-[:COLLECTED_BY]->(o:Organization)
    OPTIONAL MATCH (c:Column)-[:SOURCE_FROM]->(s)
    OPTIONAL MATCH (t:Table)-[:HAS_COLUMN]->(c)
    RETURN s.code AS source_code, s.name AS source_name,
           s.shakl AS shakl, s.davriylik AS davriylik,
           s.qamrov AS qamrov, s.asos_band AS asos_band,
           coalesce(o.qisqa, o.name) AS organization,
           collect(DISTINCT t.name)[0..5] AS tables
    LIMIT $limit
    """
    rows = run_cypher(
        cypher,
        {"q": q or "", "code": code or "", "limit": limit},
    )
    if rows:
        return _ok("sources", cypher_name="source_org", params={"q": q}, rows=rows)

    # Fallback: indicator → report → table → column → source
    cypher2 = """
    MATCH (i:Indicator)
    WHERE ($code <> '' AND i.code = $code)
       OR ($q <> '' AND toLower(coalesce(i.name,'')) CONTAINS toLower($q))
    OPTIONAL MATCH (i)-[:REPORTED_IN]->(r:Report)
    OPTIONAL MATCH (r)-[:HAS_TABLE]->(t:Table)
    OPTIONAL MATCH (t)-[:HAS_COLUMN]->(c:Column)
    OPTIONAL MATCH (c)-[:SOURCE_FROM]->(s:Source)
    OPTIONAL MATCH (s)-[:COLLECTED_BY]->(o:Organization)
    RETURN i.code AS indicator_code, i.name AS indicator_name,
           r.name AS report, t.name AS table,
           s.code AS source_code, s.name AS source_name, s.shakl AS shakl,
           coalesce(o.qisqa, o.name) AS organization
    LIMIT $limit
    """
    rows2 = run_cypher(cypher2, {"q": q or "", "code": code or "", "limit": limit})
    return _ok(
        "sources",
        cypher_name="indicator_report_source_chain",
        params={"q": q},
        rows=rows2,
    )


def _run_search(run_cypher, *, question: str, limit: int) -> dict[str, Any]:
    q = (question or "").strip()
    if not q:
        return {
            "success": False,
            "error": "search needs question text",
            "error_code": "validation",
            "intent": "search",
        }
    # Prefer fulltext if available; fall back to CONTAINS
    try:
        cypher_ft = """
        CALL db.index.fulltext.queryNodes('ft_indicator', $q) YIELD node, score
        RETURN 'Indicator' AS label, node.code AS code, node.name AS name,
               score AS score
        ORDER BY score DESC
        LIMIT $limit
        """
        rows = run_cypher(cypher_ft, {"q": q, "limit": limit})
        if rows:
            return _ok("search", cypher_name="fulltext_indicator", params={"q": q}, rows=rows)
    except Exception as exc:  # noqa: BLE001
        logger.debug("fulltext ft_indicator skipped: %s", exc)

    try:
        cypher_ft2 = """
        CALL db.index.fulltext.queryNodes('ft_paragraph', $q) YIELD node, score
        RETURN 'Paragraph' AS label, toString(node.number) AS code,
               coalesce(node.title, '') AS name,
               score AS score
        ORDER BY score DESC
        LIMIT $limit
        """
        rows = run_cypher(cypher_ft2, {"q": q, "limit": limit})
        if rows:
            return _ok("search", cypher_name="fulltext_paragraph", params={"q": q}, rows=rows)
    except Exception as exc:  # noqa: BLE001
        logger.debug("fulltext ft_paragraph skipped: %s", exc)

    cypher = """
    MATCH (i:Indicator)
    WHERE toLower(coalesce(i.name,'')) CONTAINS toLower($q)
       OR toLower(coalesce(i.code,'')) CONTAINS toLower($q)
    RETURN 'Indicator' AS label, i.code AS code, i.name AS name, 1.0 AS score
    LIMIT $limit
    """
    rows = run_cypher(cypher, {"q": q, "limit": limit})
    return _ok("search", cypher_name="contains_indicator", params={"q": q}, rows=rows)


def _ok(
    intent: str,
    *,
    cypher_name: str,
    params: dict[str, Any],
    rows: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "success": True,
        "intent": intent,
        "cypher_name": cypher_name,
        "params": params,
        "row_count": len(rows),
        "rows": rows,
        "error": None,
        "agent": "QXAudit.graph",
        "mode": "template_cypher",
    }


def format_for_host(result: dict[str, Any]) -> str:
    """Plain text for the host LLM (never raw errors only)."""
    if result.get("error_code") == "ambiguous":
        lines = [
            "graph_ask: SAVOL ANIQ EMAS — javob berilmadi.",
            str(result.get("error") or ""),
            "Variantlar:",
        ]
        for i, c in enumerate(result.get("candidates") or [], 1):
            qiymat = c.get("qiymat_2026")
            extra = f" — {qiymat} mlrd so'm" if qiymat is not None else ""
            lines.append(f"  {i}. {c.get('code')}: {c.get('name')}{extra}")
        lines.append(
            "Foydalanuvchidan qaysi birini nazarda tutganini so'rang va javobini "
            "olgach graph_ask ni code= bilan qayta chaqiring. O'zingiz tanlamang."
        )
        return "\n".join(x for x in lines if x)
    if not result.get("success"):
        return (
            f"graph_ask xato: {result.get('error')} "
            f"(code={result.get('error_code')}, intent={result.get('intent')})"
        )
    lines = [
        f"intent={result.get('intent')} template={result.get('cypher_name')} "
        f"rows={result.get('row_count')}",
    ]
    if result.get("message"):
        lines.append(str(result["message"]))
    for i, row in enumerate(result.get("rows") or [], 1):
        if not isinstance(row, dict):
            lines.append(f"{i}. {row}")
            continue
        # Prefer readable fields
        parts = []
        for k, v in row.items():
            if v is None or v == "" or v == []:
                continue
            if isinstance(v, str) and len(v) > 400:
                v = v[:400] + "…"
            parts.append(f"{k}={v}")
        lines.append(f"{i}. " + "; ".join(parts))
    if result.get("candidates") and len(result["candidates"]) > 1:
        lines.append("Boshqa kandidatlar:")
        for c in result["candidates"][:5]:
            lines.append(f"  - {c.get('code')}: {c.get('name')}")
    if not result.get("rows"):
        lines.append("(bo'sh natija)")
    return "\n".join(lines)
