#!/usr/bin/env python3
"""
heuristic_origin.py — Assigne une origine probable aux prénoms encore NULL
                       via des règles morphologiques, puis tague le reste "Autre".

Étapes :
  1. Applique ~30 règles morphologiques (suffixes, préfixes, patterns)
  2. Marque origin_source = 'heuristic' pour ces assignations
  3. Tague tous les prénoms encore NULL → origin = 'Autre', origin_source = 'fallback'

Usage:
    python3 scripts/heuristic_origin.py
    python3 scripts/heuristic_origin.py --no-fallback   # skip étape 3
    python3 scripts/heuristic_origin.py --dry-run       # affiche sans écrire
    python3 scripts/heuristic_origin.py --report-only   # juste les stats
"""
from __future__ import annotations

import argparse
import re
import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).parent.parent / "Resources" / "names.sqlite"

# ── Règles morphologiques ─────────────────────────────────────────────────────
# Format : (pattern_regex, origin, description)
# L'ordre compte : la première règle qui matche gagne.
# Toutes les comparaisons sont faites sur le nom en minuscules.

RULES: list[tuple[re.Pattern, str, str]] = [
    # ── Irlandais ─────────────────────────────────────────────────────────
    (re.compile(r"^(mc|mac|o')[a-z]", re.IGNORECASE), "Irlandais", "Préfixe Mc/Mac/O'"),
    (re.compile(r"^fitz[a-z]",        re.IGNORECASE), "Normand",   "Préfixe Fitz"),

    # ── Grec ──────────────────────────────────────────────────────────────
    (re.compile(r"(akis|opoulos|opoulou|ides|adis|idis)$", re.IGNORECASE), "Grec", "Suffixe grec"),

    # ── Slave ─────────────────────────────────────────────────────────────
    (re.compile(r"(ova|eva|ski|sky|czyk|wicz|wska|owski|owska|enko|chuk)$", re.IGNORECASE), "Slave", "Suffixe slave"),

    # ── Nordique ──────────────────────────────────────────────────────────
    (re.compile(r"(sson|rsson|dsson)$", re.IGNORECASE), "Nordique", "Suffixe nordique -sson"),

    # ── Germanique ────────────────────────────────────────────────────────
    (re.compile(r"(bert|bald|wald|mund|hardt|helm|ulf|bold)$", re.IGNORECASE), "Germanique", "Suffixe germanique"),

    # ── Normand ───────────────────────────────────────────────────────────
    # -aud/-ault sont fiables (Renaud, Thibault) mais -eau trop ambiguë
    (re.compile(r"(ault|aud)$", re.IGNORECASE), "Normand", "Suffixe normand -aud/-ault"),

    # ── Gallois ───────────────────────────────────────────────────────────
    (re.compile(r"(wyn|aeth|llyr)$",           re.IGNORECASE), "Gallois", "Suffixe gallois"),
    (re.compile(r"^(rhys|llew|gwyn|cadw|caer)", re.IGNORECASE), "Gallois", "Préfixe gallois"),

    # ── Breton ────────────────────────────────────────────────────────────
    (re.compile(
        r"^(gwenn?|erwan|enora|ga[eë]l|ronan|tifenn|nolwenn|soazig|korentin|tugdual|gurvan|loïg|paol)",
        re.IGNORECASE), "Breton", "Prénom breton connu"),

    # ── Arabe ─────────────────────────────────────────────────────────────
    # Placer Arabe AVANT Hébreu pour les suffixes ambigus (-yah peut être Arabe: Aaliyah)
    (re.compile(r"^(abd[ae]l?|abou|abû|ahmed?|bou|dja|fath|fatou?|hass?an|ibr|isl|isma|khal|moha?m|mous|must|ouss|ousm|rahm|sidi|soum|yous)", re.IGNORECASE), "Arabe", "Préfixe arabe"),
    (re.compile(r"(eddine|eddîne|ddin|allah|ullah)$", re.IGNORECASE), "Arabe",  "Suffixe arabe -eddine/-allah"),
    # -iyah commun en arabe (Aaliyah, Mariyah, Khadijah) — AVANT -yah hébreu
    (re.compile(r"(iyah|ijah)$", re.IGNORECASE), "Arabe", "Suffixe arabe -iyah/-ijah"),

    # ── Hébreu ────────────────────────────────────────────────────────────
    # -iel/-ael très fiables (Gabriel, Nathanael, Ariel)
    (re.compile(r"(iel|ael|eel)$", re.IGNORECASE), "Hébreu", "Suffixe hébreu -iel/-ael"),
    # -yah/-yahu fiables pour les noms franchement bibliques (Isaiah, Zechariah)
    (re.compile(r"(yahu|aiah)$", re.IGNORECASE), "Hébreu", "Suffixe hébreu -yahu/-aiah"),
    (re.compile(r"^(eli[a-z]|elah|ezr|shm|shlom|yoch|yoha|zach)", re.IGNORECASE), "Hébreu", "Préfixe hébreu"),

    # ── Japonais ──────────────────────────────────────────────────────────
    # -ko très fiable (Yumiko, Hanako, Sachiko) ; -michi/-hiro moins
    (re.compile(r"(ko|michi|hiro|taro|saburo|kazuo|nobuko)$", re.IGNORECASE), "Japonais", "Suffixe japonais -ko/-michi"),

    # ── Sanskrit / Indien ─────────────────────────────────────────────────
    # Avant Espagnol pour éviter que -ita attrape des noms indiens
    (re.compile(r"(ananda|devi|priya|shri|krishna|shiva|lakshmi|ganesha|dharma)$", re.IGNORECASE), "Sanskrit", "Suffixe sanskrit"),
    (re.compile(r"^(anand|dhruv|hari|krish|priy|rishi|shri|vish|yog)", re.IGNORECASE), "Sanskrit", "Préfixe sanskrit"),

    # ── Espagnol ──────────────────────────────────────────────────────────
    # -ita/-ito uniquement précédés d'une consonne (Juanita, Pepito) pour éviter Bonita ambigu
    (re.compile(r"[bcdfghjklmnpqrstvwxyz](ita|ito)$", re.IGNORECASE), "Espagnol", "Diminutif espagnol -ita/-ito"),
    (re.compile(r"^(alf?onso|benit|conch|consuel|doming|esper|fernan|guill?erm|ignac|joaqu|ximena|soledad|pilar)", re.IGNORECASE), "Espagnol", "Prénom espagnol connu"),

    # ── Germanique (préfixes communs) ────────────────────────────────────
    # Après Arabe/Hébreu pour éviter collisions sur -al-
    (re.compile(r"^(ald|alf|ger|god|gun|hug|lud|wig)[a-z]{2}", re.IGNORECASE), "Germanique", "Préfixe germanique"),

    # ── Latin ─────────────────────────────────────────────────────────────
    # Uniquement les terminaisons les plus spécifiques
    (re.compile(r"(ianus|ianus)$", re.IGNORECASE), "Latin", "Terminaison latine -ianus"),
    (re.compile(r"ius$",           re.IGNORECASE), "Latin", "Terminaison latine -ius"),
]

# Deduplication: keep only unique patterns
_SEEN_PATTERNS: set[str] = set()
_UNIQUE_RULES: list[tuple[re.Pattern, str, str]] = []
for pat, origin, desc in RULES:
    if pat.pattern not in _SEEN_PATTERNS:
        _SEEN_PATTERNS.add(pat.pattern)
        _UNIQUE_RULES.append((pat, origin, desc))
RULES = _UNIQUE_RULES


# ── DB helpers ────────────────────────────────────────────────────────────────

def _ensure_origin_source_column(con: sqlite3.Connection) -> None:
    cols = {row[1] for row in con.execute("PRAGMA table_info(names)")}
    if "origin_source" not in cols:
        con.execute("ALTER TABLE names ADD COLUMN origin_source TEXT")
        con.commit()
        print("  + Added column origin_source")


def _classify(name: str) -> Optional[tuple[str, str]]:
    """Returns (origin, rule_description) or None."""
    for pat, origin, desc in RULES:
        if pat.search(name):
            return origin, desc
    return None


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-fallback", action="store_true",
                        help="Ne pas assigner 'Autre' aux NULL persistants")
    parser.add_argument("--dry-run",     action="store_true",
                        help="Affiche les résultats sans écrire dans la DB")
    parser.add_argument("--report-only", action="store_true",
                        help="Affiche uniquement les statistiques actuelles")
    args = parser.parse_args()

    if not DB_PATH.exists():
        raise SystemExit(f"DB not found: {DB_PATH}")

    con = sqlite3.connect(DB_PATH)
    _ensure_origin_source_column(con)

    if args.report_only:
        _print_report(con)
        con.close()
        return

    # ── Step 1 & 2: heuristic rules ──────────────────────────────────────
    null_names = con.execute(
        "SELECT DISTINCT name FROM names WHERE origin IS NULL ORDER BY name"
    ).fetchall()
    null_names = [r[0] for r in null_names]

    print(f"\n[Heuristic] {len(null_names):,} NULL-origin names to classify\n")

    heuristic_results: dict[str, tuple[str, str]] = {}
    for name in null_names:
        result = _classify(name)
        if result:
            heuristic_results[name] = result

    print(f"  Matched by heuristic : {len(heuristic_results):,}")
    print(f"  Still unclassified   : {len(null_names) - len(heuristic_results):,}")

    if args.dry_run:
        print("\n── Sample heuristic matches ─────────────────────────────")
        for name, (origin, desc) in list(heuristic_results.items())[:40]:
            print(f"  {name:<20} → {origin:<15} ({desc})")
        print("\n[DRY-RUN] No changes written.")
        con.close()
        return

    # Apply heuristic results
    heuristic_count = 0
    for name, (origin, _desc) in heuristic_results.items():
        con.execute(
            "UPDATE names SET origin = ?, origin_source = 'heuristic' WHERE name = ? AND origin IS NULL",
            (origin, name),
        )
        heuristic_count += 1
    con.commit()
    print(f"\n✓ Heuristic origins written : {heuristic_count:,}")

    # ── Step 3: fallback "Autre" ──────────────────────────────────────────
    if not args.no_fallback:
        cur = con.execute(
            "UPDATE names SET origin = 'Autre', origin_source = 'fallback' WHERE origin IS NULL"
        )
        fallback_count = cur.rowcount
        con.commit()
        print(f"✓ Fallback 'Autre' applied   : {fallback_count:,}")

    _print_report(con)
    con.close()


def _print_report(con: sqlite3.Connection) -> None:
    total       = con.execute("SELECT COUNT(*) FROM names").fetchone()[0]
    with_origin = con.execute("SELECT COUNT(*) FROM names WHERE origin IS NOT NULL").fetchone()[0]
    still_null  = con.execute("SELECT COUNT(*) FROM names WHERE origin IS NULL").fetchone()[0]
    pct         = 100 * with_origin // total if total else 0

    print(f"\n── Coverage report ──────────────────────────────────────")
    print(f"  Total names    : {total:,}")
    print(f"  With origin    : {with_origin:,}  ({pct}%)")
    print(f"  Still NULL     : {still_null:,}")

    print(f"\n── By origin_source ─────────────────────────────────────")
    rows = con.execute(
        "SELECT COALESCE(origin_source, 'original') AS src, COUNT(*) AS n "
        "FROM names GROUP BY src ORDER BY n DESC"
    ).fetchall()
    for src, n in rows:
        bar = "█" * min(40, n * 40 // total)
        print(f"  {src:<12} {n:>7,}  {bar}")

    print(f"\n── Top origins (post-enrichment) ───────────────────────")
    rows = con.execute(
        "SELECT origin, COUNT(*) AS n FROM names WHERE origin IS NOT NULL "
        "GROUP BY origin ORDER BY n DESC LIMIT 20"
    ).fetchall()
    for origin, n in rows:
        pct_o = 100 * n // total
        print(f"  {origin:<18} {n:>7,}  {pct_o}%")
    print()


# ── Type alias (Python 3.9 compat) ───────────────────────────────────────────
from typing import Optional  # noqa: E402

if __name__ == "__main__":
    main()
