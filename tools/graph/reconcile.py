"""
Deterministic reconciliation checks for the YaICh knowledge graph.

Every identity required by the methodology (30-band aggregation tree,
FHI x deflator, regional and producer-category breakdowns) is verified in
Python from graph values. The LLM never computes a number here — it only
relays what this module returns.

Design notes:
  * PASS / FAIL / SKIP — SKIP is used whenever the data needed for a verdict is
    absent, so a missing extension layer never looks like a passing check.
  * No check decides which of two conflicting figures is correct; that is a
    human decision, flagged with requires_human_decision.
"""

from __future__ import annotations

import logging
from typing import Any, Callable, Optional

logger = logging.getLogger("graph_reconcile")

CHECKS: tuple[str, ...] = (
    "aggregate_sums",
    "fhi_deflator_identity",
    "valovka_variance",
    "region_sum",
    "category_sum",
)

# Money values live on a year-suffixed property in the current ontology.
# Module constants, never user input — safe to interpolate into Cypher.
VALUE_PROP = "qiymat_2026_mlrd_som"
VALOVKA_PROP = "qiymat_2026_valovka_mlrd_som"

DEFAULT_TOLERANCE_MLRD = 0.5
DEFAULT_TOLERANCE_PERCENT = 0.2

# Producer-category figures in the source workbook cover section 01 only.
CATEGORY_TARGET_CODE = "IND_VII"
TOTAL_CODE = "IND_X"


def list_checks() -> list[dict[str, str]]:
    return [
        {
            "name": "aggregate_sums",
            "description": (
                "Har bir agregat ko'rsatkich CALCULATED_FROM qismlari "
                "yig'indisiga tengmi (24, 26, 30-bandlar)"
            ),
        },
        {
            "name": "fhi_deflator_identity",
            "description": "FHI x Deflyator = Nominal o'zgarish (tekshiruv ayniyati)",
        },
        {
            "name": "valovka_variance",
            "description": "'Respublika' va 'valovka' varaqlari o'rtasidagi sverka farqi",
        },
        {
            "name": "region_sum",
            "description": "Hududlar yig'indisi respublika jamiga tengmi",
        },
        {
            "name": "category_sum",
            "description": "Ishlab chiqaruvchilar toifalari yig'indisi 01-bo'limga tengmi",
        },
    ]


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------


def _num(val: Any) -> Optional[float]:
    if val is None:
        return None
    try:
        return float(val)
    except (TypeError, ValueError):
        return None


def _r(val: Optional[float], n: int = 1) -> Optional[float]:
    return None if val is None else round(val, n)


def _base(check: str, title: str, *, basis_band: Any = None) -> dict[str, Any]:
    return {"check": check, "title": title, "basis_band": basis_band}


def _skip(
    check: str, title: str, *, reason: str, basis_band: Any = None
) -> dict[str, Any]:
    out = _base(check, title, basis_band=basis_band)
    out.update(
        {
            "status": "SKIP",
            "severity": "info",
            "explanation": reason,
            "requires_human_decision": False,
        }
    )
    return out


def _verdict(
    check: str,
    title: str,
    *,
    expected: Optional[float],
    actual: Optional[float],
    tolerance: float,
    unit: str,
    basis_band: Any = None,
    explanation: str = "",
    severity_on_fail: str = "high",
    requires_human_decision: bool = False,
    extra: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    out = _base(check, title, basis_band=basis_band)
    diff = None
    if expected is not None and actual is not None:
        diff = round(expected - actual, 2)
    ok = diff is not None and abs(diff) <= tolerance
    out.update(
        {
            "status": "PASS" if ok else "FAIL",
            "expected": _r(expected, 2),
            "actual": _r(actual, 2),
            "diff": diff,
            "unit": unit,
            "tolerance": tolerance,
            "severity": "ok" if ok else severity_on_fail,
            "explanation": explanation,
            "requires_human_decision": bool(requires_human_decision and not ok),
        }
    )
    if extra:
        out.update(extra)
    return out


# ---------------------------------------------------------------------------
# checks
# ---------------------------------------------------------------------------


def _check_aggregate_sums(
    run_cypher: Callable, ctx: dict[str, Any]
) -> list[dict[str, Any]]:
    """Every aggregate indicator vs the sum of its CALCULATED_FROM parts."""
    cypher = """
    MATCH (p:Indicator)-[r:CALCULATED_FROM]->(c:Indicator)
    WHERE p.turi = 'agregat' AND p.%(v)s IS NOT NULL
    WITH p,
         head(collect(r.asos)) AS asos,
         collect({code: c.code, name: c.name, value: c.%(v)s}) AS parts
    RETURN p.code AS parent_code, p.name AS parent_name,
           p.%(v)s AS parent_value, asos, parts
    ORDER BY parent_code
    """ % {"v": VALUE_PROP}
    rows = run_cypher(cypher, {})
    if not rows:
        return [
            _skip(
                "aggregate_sums",
                "Agregat yig'indilari",
                reason=(
                    "Grafda CALCULATED_FROM bog'langan agregat ko'rsatkich topilmadi"
                ),
            )
        ]

    tol = ctx["tolerance_mlrd"]
    out: list[dict[str, Any]] = []
    for row in rows:
        parent_value = _num(row.get("parent_value"))
        parts = [p for p in (row.get("parts") or []) if isinstance(p, dict)]
        known = [p for p in parts if _num(p.get("value")) is not None]
        missing = [p for p in parts if _num(p.get("value")) is None]
        title = "{} = qismlari yig'indisi".format(row.get("parent_code"))
        band = row.get("asos")

        if not known:
            out.append(
                _skip(
                    "aggregate_sums",
                    title,
                    reason=(
                        "{}: barcha {} ta tarkibiy qismning qiymati grafda yo'q".format(
                            row.get("parent_name"), len(parts)
                        )
                    ),
                    basis_band=band,
                )
            )
            continue

        total = sum(_num(p["value"]) or 0.0 for p in known)
        if missing:
            names = ", ".join(str(p.get("code")) for p in missing[:5])
            entry = _skip(
                "aggregate_sums",
                title,
                reason=(
                    "{} ta qismning qiymati yo'q ({}) — yig'indi to'liq emas, "
                    "xulosa chiqarib bo'lmaydi".format(len(missing), names)
                ),
                basis_band=band,
            )
            entry.update(
                {
                    "parent": {
                        "code": row.get("parent_code"),
                        "name": row.get("parent_name"),
                    },
                    "expected": _r(parent_value),
                    "partial_sum": _r(total),
                    "missing_parts": [
                        {"code": p.get("code"), "name": p.get("name")} for p in missing
                    ],
                    "severity": "medium",
                }
            )
            out.append(entry)
            continue

        out.append(
            _verdict(
                "aggregate_sums",
                title,
                expected=parent_value,
                actual=total,
                tolerance=tol,
                unit="mlrd so'm",
                basis_band=band,
                explanation="{} — {} ta qismdan yig'ildi".format(
                    row.get("parent_name"), len(known)
                ),
                requires_human_decision=True,
                extra={
                    "parent": {
                        "code": row.get("parent_code"),
                        "name": row.get("parent_name"),
                    },
                    "parts": [
                        {
                            "code": p.get("code"),
                            "name": p.get("name"),
                            "value": _r(_num(p.get("value"))),
                        }
                        for p in known
                    ],
                },
            )
        )
    return out


def _check_fhi_deflator_identity(
    run_cypher: Callable, ctx: dict[str, Any]
) -> list[dict[str, Any]]:
    """FHI x Deflator / 100 = nominal change."""
    cypher = """
    MATCH (f:Indicator {code:'IND_FHI'})
    MATCH (d:Indicator {code:'IND_DEFLYATOR'})
    MATCH (n:Indicator {code:'IND_NOMINAL'})
    RETURN f.qiymat_foiz AS fhi, d.qiymat_foiz AS deflyator,
           n.qiymat_foiz AS nominal
    """
    rows = run_cypher(cypher, {})
    title = "FHI x Deflyator = Nominal o'zgarish"
    if not rows:
        return [
            _skip(
                "fhi_deflator_identity",
                title,
                reason="IND_FHI / IND_DEFLYATOR / IND_NOMINAL tugunlari topilmadi",
            )
        ]
    row = rows[0]
    fhi = _num(row.get("fhi"))
    defl = _num(row.get("deflyator"))
    nominal = _num(row.get("nominal"))
    if fhi is None or defl is None or nominal is None:
        return [
            _skip(
                "fhi_deflator_identity",
                title,
                reason="Indekslardan birining qiymat_foiz qiymati yo'q",
            )
        ]
    computed = fhi * defl / 100.0
    return [
        _verdict(
            "fhi_deflator_identity",
            title,
            expected=nominal,
            actual=computed,
            tolerance=ctx["tolerance_percent"],
            unit="%",
            basis_band="37-41-bandlar",
            explanation="{} x {} / 100 = {}".format(fhi, defl, round(computed, 2)),
            severity_on_fail="high",
            requires_human_decision=True,
            extra={"fhi": fhi, "deflyator": defl},
        )
    ]


def _check_valovka_variance(
    run_cypher: Callable, ctx: dict[str, Any]
) -> list[dict[str, Any]]:
    """'Respublika' sheet vs 'valovka' sheet for the section-A total."""
    cypher = """
    MATCH (i:Indicator {code: $code})
    RETURN i.code AS code, i.name AS name,
           i.%(v)s AS respublika, i.%(w)s AS valovka,
           i.deflyator_foiz AS deflyator, i.izoh AS izoh
    """ % {"v": VALUE_PROP, "w": VALOVKA_PROP}
    rows = run_cypher(cypher, {"code": TOTAL_CODE})
    title = "Vv(A): 'Respublika' va 'valovka' varaqlari sverkasi"
    if not rows:
        return [
            _skip("valovka_variance", title, reason="{} topilmadi".format(TOTAL_CODE))
        ]
    row = rows[0]
    resp = _num(row.get("respublika"))
    valovka = _num(row.get("valovka"))
    if valovka is None:
        return [
            _skip(
                "valovka_variance",
                title,
                reason=(
                    "{} xossasi yo'q — solishtirish uchun ikkinchi qiymat "
                    "topilmadi".format(VALOVKA_PROP)
                ),
                basis_band=30,
            )
        ]
    return [
        _verdict(
            "valovka_variance",
            title,
            expected=resp,
            actual=valovka,
            tolerance=ctx["tolerance_mlrd"],
            unit="mlrd so'm",
            basis_band=30,
            explanation=(
                "Ikki manba varag'i bir xil ko'rsatkich uchun turli qiymat beradi. "
                "Qaysi biri yakuniy ekanini tizim hal qilmaydi."
            ),
            severity_on_fail="high",
            requires_human_decision=True,
            extra={"izoh": row.get("izoh")},
        )
    ]


def _check_region_sum(
    run_cypher: Callable, ctx: dict[str, Any]
) -> list[dict[str, Any]]:
    """Sum of regional observations vs the republic-level observation."""
    cypher = """
    MATCH (o:Observation)-[:IN_REGION]->(r:Region)
    WHERE o.kesim = 'hudud'
    OPTIONAL MATCH (o)-[:FOR_PERIOD]->(pr:Period)
    RETURN r.code AS region_code, r.name AS region_name,
           o.qiymat AS value, pr.code AS period, o.ind AS indicator
    """
    rows = run_cypher(cypher, {})
    title = "Hududlar yig'indisi = Respublika jami"
    if not rows:
        return [
            _skip(
                "region_sum",
                title,
                reason=(
                    "Observation/Region qatlami grafda yo'q — "
                    "knowledge/02_kengaytma_kesimlar.cypher yuklanmagan"
                ),
            )
        ]
    period = ctx.get("period")
    if period:
        rows = [r for r in rows if not r.get("period") or r.get("period") == period]
    total_row = next((r for r in rows if r.get("region_code") == "R_UZ"), None)
    parts = [
        r
        for r in rows
        if r.get("region_code") != "R_UZ" and _num(r.get("value")) is not None
    ]
    if total_row is None or _num(total_row.get("value")) is None:
        return [
            _skip("region_sum", title, reason="R_UZ (respublika) kuzatuvi topilmadi")
        ]
    if not parts:
        return [_skip("region_sum", title, reason="Hududiy kuzatuvlar topilmadi")]
    total = sum(_num(r.get("value")) or 0.0 for r in parts)
    return [
        _verdict(
            "region_sum",
            title,
            expected=_num(total_row.get("value")),
            actual=total,
            tolerance=ctx["tolerance_mlrd"],
            unit="mlrd so'm",
            basis_band=8,
            explanation="{} ta hudud bo'yicha yig'indi".format(len(parts)),
            requires_human_decision=True,
            extra={"region_count": len(parts)},
        )
    ]


def _check_category_sum(
    run_cypher: Callable, ctx: dict[str, Any]
) -> list[dict[str, Any]]:
    """Producer categories vs the section-01 total they are drawn from."""
    cypher = """
    MATCH (c:ProducerCategory)
    WHERE c.daraja = 'toifa' AND c.%(v)s IS NOT NULL
    RETURN c.code AS code, c.name AS name, c.%(v)s AS value
    ORDER BY code
    """ % {"v": VALUE_PROP}
    rows = run_cypher(cypher, {})
    title = "Toifalar yig'indisi = 01-bo'lim jami"
    if not rows:
        return [
            _skip(
                "category_sum",
                title,
                reason=(
                    "ProducerCategory qatlami grafda yo'q — "
                    "knowledge/02_kengaytma_kesimlar.cypher yuklanmagan"
                ),
                basis_band=8,
            )
        ]
    target_rows = run_cypher(
        "MATCH (i:Indicator {code: $code}) RETURN i.%s AS value, i.name AS name"
        % VALUE_PROP,
        {"code": CATEGORY_TARGET_CODE},
    )
    target = _num(target_rows[0].get("value")) if target_rows else None
    total = sum(_num(r.get("value")) or 0.0 for r in rows)
    if target is None:
        entry = _skip(
            "category_sum",
            title,
            reason=(
                "{} qiymati yo'q — solishtirish uchun asos topilmadi".format(
                    CATEGORY_TARGET_CODE
                )
            ),
            basis_band=8,
        )
        entry.update({"actual": _r(total), "categories": len(rows)})
        return [entry]
    return [
        _verdict(
            "category_sum",
            title,
            expected=target,
            actual=total,
            tolerance=ctx["tolerance_mlrd"],
            unit="mlrd so'm",
            basis_band=8,
            explanation=(
                "{} ta toifa yig'indisi {} (01-bo'lim) bilan solishtirildi".format(
                    len(rows), CATEGORY_TARGET_CODE
                )
            ),
            requires_human_decision=True,
            extra={
                "categories": [
                    {"code": r.get("code"), "value": _r(_num(r.get("value")))}
                    for r in rows
                ]
            },
        )
    ]


_RUNNERS: dict[str, Callable[[Callable, dict[str, Any]], list[dict[str, Any]]]] = {
    "aggregate_sums": _check_aggregate_sums,
    "fhi_deflator_identity": _check_fhi_deflator_identity,
    "valovka_variance": _check_valovka_variance,
    "region_sum": _check_region_sum,
    "category_sum": _check_category_sum,
}


# ---------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------


def reconcile_check(
    *,
    checks: Optional[list[str]] = None,
    tolerance_mlrd: float = DEFAULT_TOLERANCE_MLRD,
    tolerance_percent: float = DEFAULT_TOLERANCE_PERCENT,
    period: str = "",
    run_cypher: Optional[Callable] = None,
) -> dict[str, Any]:
    """
    Run reconciliation checks against the graph. Never raises to callers.

    run_cypher is injectable so the checks can be tested without Neo4j.
    """
    if run_cypher is None:
        from agents.neo4j_client import is_enabled
        from agents.neo4j_client import run_cypher as _rc

        if not is_enabled():
            return {
                "success": False,
                "error": "Neo4j disabled (NEO4J_ENABLED=false)",
                "error_code": "disabled",
            }
        run_cypher = _rc

    wanted = [str(c).strip() for c in (checks or list(CHECKS)) if str(c).strip()]
    unknown = [c for c in wanted if c not in _RUNNERS]
    if unknown:
        return {
            "success": False,
            "error": "unknown check(s): {}; allowed={}".format(unknown, list(CHECKS)),
            "error_code": "validation",
        }

    ctx = {
        "tolerance_mlrd": float(tolerance_mlrd),
        "tolerance_percent": float(tolerance_percent),
        "period": (period or "").strip(),
    }

    results: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []
    for name in wanted:
        try:
            results.extend(_RUNNERS[name](run_cypher, ctx))
        except Exception as exc:  # noqa: BLE001
            logger.error("reconcile check %s failed: %s", name, exc, exc_info=True)
            errors.append({"check": name, "error": str(exc)})

    order = {"FAIL": 0, "SKIP": 1, "PASS": 2}
    results.sort(
        key=lambda r: (order.get(str(r.get("status")), 3), str(r.get("check")))
    )

    summary = {
        "passed": sum(1 for r in results if r.get("status") == "PASS"),
        "failed": sum(1 for r in results if r.get("status") == "FAIL"),
        "skipped": sum(1 for r in results if r.get("status") == "SKIP"),
        "high_severity": sum(1 for r in results if r.get("severity") == "high"),
        "needs_decision": sum(1 for r in results if r.get("requires_human_decision")),
    }
    return {
        "success": True,
        "checks_run": wanted,
        "period": ctx["period"] or None,
        "tolerance": {
            "mlrd": ctx["tolerance_mlrd"],
            "percent": ctx["tolerance_percent"],
        },
        "results": results,
        "summary": summary,
        "errors": errors or None,
        "error": None,
        "agent": "QXAudit.graph",
        "mode": "deterministic_reconcile",
    }


def format_for_host(result: dict[str, Any]) -> str:
    """Plain text for the host LLM."""
    if not result.get("success"):
        return "reconcile_check xato: {} (code={})".format(
            result.get("error"), result.get("error_code")
        )
    s = result.get("summary") or {}
    lines = [
        "reconcile_check: {} PASS · {} FAIL · {} SKIP".format(
            s.get("passed", 0), s.get("failed", 0), s.get("skipped", 0)
        )
    ]
    icon = {"PASS": "[OK]", "FAIL": "[XATO]", "SKIP": "[TEKSHIRILMADI]"}
    for r in result.get("results") or []:
        head = "{} {}".format(icon.get(str(r.get("status")), "[?]"), r.get("title"))
        if r.get("basis_band"):
            head += " ({})".format(r["basis_band"])
        lines.append(head)
        if r.get("status") == "FAIL":
            lines.append(
                "    kutilgan={} hisoblangan={} farq={} {}".format(
                    r.get("expected"), r.get("actual"), r.get("diff"),
                    r.get("unit") or "",
                )
            )
        if r.get("explanation"):
            lines.append("    {}".format(r["explanation"]))
        if r.get("missing_parts"):
            miss = ", ".join(str(m.get("code")) for m in r["missing_parts"][:5])
            lines.append("    qiymati yo'q: {}".format(miss))
    if s.get("needs_decision"):
        lines.append(
            "DIQQAT: {} ta nomuvofiqlik odam qaroriga muhtoj — qaysi qiymat "
            "to'g'ri ekanini o'zing hal qilma, foydalanuvchidan so'ra.".format(
                s["needs_decision"]
            )
        )
    for e in result.get("errors") or []:
        lines.append("[XATOLIK] {}: {}".format(e.get("check"), e.get("error")))
    return "\n".join(lines)
