#!/usr/bin/env python3
"""
enrich_missing_origins.py — Re-enrichit les prénoms sans origine via Wikidata.

Cible : names WHERE origin IS NULL AND (popularity_rank_fr <= 5000 OR popularity_rank_us <= 5000)
Stratégie : Wikidata SPARQL avec retry exponentiel (1s, 3s, 9s), cache local réutilisé.
Ajoute la colonne origin_source si absente (valeur 'wikidata' pour les matchs trouvés).

Usage:
    python3 scripts/enrich_missing_origins.py
    python3 scripts/enrich_missing_origins.py --all-null    # cible TOUS les NULL (lent)
    python3 scripts/enrich_missing_origins.py --dry-run     # affiche sans écrire
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import time
from pathlib import Path
from typing import Optional

import requests

# ── Paths ────────────────────────────────────────────────────────────────────
ROOT           = Path(__file__).parent.parent
DATA_CACHE     = ROOT / "data" / "cache"
DB_PATH        = ROOT / "Resources" / "names.sqlite"
ENRICH_CACHE   = DATA_CACHE / "enrich_missing_cache.json"
WIKIDATA_CACHE = DATA_CACHE / "wikidata_cache.json"

# ── Wikidata config ───────────────────────────────────────────────────────────
WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
WIKIDATA_HEADERS  = {
    "User-Agent": "PrenommeApp/1.0 (github.com/sacha9955/Prenomme) enrich_missing_origins.py",
    "Accept":     "application/sparql-results+json",
}
BATCH_SIZE         = 80
BATCH_SLEEP        = 1.5   # seconds between successful batches
RETRY_DELAYS       = [1.0, 3.0, 9.0]   # exponential back-off on error
CACHE_SAVE_EVERY   = 30    # batches between cache saves

# ── Origin detection tables (copied from import_names.py) ────────────────────
_P407_TO_ORIGIN: dict[str, str] = {
    "hébreu":             "Hébreu",
    "hébreu biblique":    "Hébreu",
    "araméen":            "Araméen",
    "latin":              "Latin",
    "latin classique":    "Latin",
    "grec ancien":        "Grec",
    "grec":               "Grec",
    "vieux haut-allemand": "Germanique",
    "vieux saxon":        "Germanique",
    "allemand":           "Germanique",
    "anglais":            "Anglais",
    "vieil anglais":      "Anglais",
    "arabe":              "Arabe",
    "arabe classique":    "Arabe",
    "breton":             "Breton",
    "vieux norrois":      "Nordique",
    "norrois":            "Nordique",
    "islandais":          "Nordique",
    "japonais":           "Japonais",
    "persan":             "Perse",
    "moyen persan":       "Perse",
    "sanskrit":           "Sanskrit",
    "irlandais médiéval": "Irlandais",
    "vieil irlandais":    "Irlandais",
    "irlandais":          "Irlandais",
    "gallois":            "Gallois",
    "espagnol":           "Espagnol",
    "basque":             "Basque",
    "occitan":            "Occitan",
    "russe":              "Slave",
    "polonais":           "Slave",
    "ukrainien":          "Ukrainien",
    "chinois":            "Chinois",
    "coréen":             "Coréen",
    "swahili":            "Swahili",
    "yoruba":             "Yoruba",
    "igbo":               "Igbo",
}

_FR_ORIGIN_KEYWORDS: dict[str, str] = {
    "hébraïque":           "Hébreu",
    "hébreu":              "Hébreu",
    "latin":               "Latin",
    "latine":              "Latin",
    "latinisé":            "Latin",
    "grec":                "Grec",
    "grecque":             "Grec",
    "germanique":          "Germanique",
    "vieux haut-allemand": "Germanique",
    "vieux saxon":         "Germanique",
    "anglais":             "Anglais",
    "anglaise":            "Anglais",
    "arabe":               "Arabe",
    "breton":              "Breton",
    "bretonne":            "Breton",
    "nordique":            "Nordique",
    "norrois":             "Nordique",
    "vieux norrois":       "Nordique",
    "scandinave":          "Nordique",
    "japonais":            "Japonais",
    "japonaise":           "Japonais",
    "persan":              "Perse",
    "perse":               "Perse",
    "sanskrit":            "Sanskrit",
    "sanscrit":            "Sanskrit",
    "védique":             "Sanskrit",
    "celtique":            "Celtique",
    "irlandais":           "Irlandais",
    "irlandaise":          "Irlandais",
    "gallois":             "Gallois",
    "galloise":            "Gallois",
    "espagnol":            "Espagnol",
    "espagnole":           "Espagnol",
    "basque":              "Basque",
    "occitan":             "Occitan",
    "occitane":            "Occitan",
    "normand":             "Normand",
    "normande":            "Normand",
    "slave":               "Slave",
    "slavon":              "Slave",
    "ukrainien":           "Ukrainien",
    "ukrainienne":         "Ukrainien",
    "chinois":             "Chinois",
    "chinoise":            "Chinois",
    "coréen":              "Coréen",
    "coréenne":            "Coréen",
    "swahili":             "Swahili",
    "yoruba":              "Yoruba",
    "igbo":                "Igbo",
    "akan":                "Akan",
    "araméen":             "Araméen",
    "araméenne":           "Araméen",
}

_EN_ORIGIN_KEYWORDS: dict[str, str] = {
    "hebrew":         "Hébreu",
    "aramaic":        "Araméen",
    "latin":          "Latin",
    "greek":          "Grec",
    "germanic":       "Germanique",
    "old high german": "Germanique",
    "english":        "Anglais",
    "old english":    "Anglais",
    "arabic":         "Arabe",
    "breton":         "Breton",
    "old norse":      "Nordique",
    "norse":          "Nordique",
    "japanese":       "Japonais",
    "persian":        "Perse",
    "sanskrit":       "Sanskrit",
    "irish":          "Irlandais",
    "welsh":          "Gallois",
    "spanish":        "Espagnol",
    "basque":         "Basque",
    "occitan":        "Occitan",
    "slavic":         "Slave",
    "ukrainian":      "Ukrainien",
    "chinese":        "Chinois",
    "korean":         "Coréen",
    "swahili":        "Swahili",
    "yoruba":         "Yoruba",
    "igbo":           "Igbo",
    "akan":           "Akan",
}

GENERIC_DESCRIPTIONS = {
    "prénom", "prénom masculin", "prénom féminin", "prénom mixte",
    "prénom masculin français", "prénom féminin français",
    "prénom épicène", "prénom épicène français",
    "male given name", "female given name", "unisex given name",
}


# ── Detection helpers ─────────────────────────────────────────────────────────

def _detect_origin_fr(desc: str) -> Optional[str]:
    desc_lower = desc.lower()
    for kw, origin in _FR_ORIGIN_KEYWORDS.items():
        if kw in desc_lower:
            return origin
    return None


def _detect_origin_en(desc: str) -> Optional[str]:
    import re as _re
    if _re.search(r"[؀-ۿ]", desc):
        return "Arabe"
    if _re.search(r"[֐-׿]", desc):
        return "Hébreu"
    if _re.search(r"[一-鿿぀-ゟ゠-ヿ]", desc):
        return "Japonais"
    if _re.search(r"[ऀ-ॿ]", desc):
        return "Sanskrit"
    desc_lower = desc.lower()
    for kw, origin in _EN_ORIGIN_KEYWORDS.items():
        if kw in desc_lower:
            return origin
    return None


def _extract_meaning(desc: str) -> Optional[str]:
    if not desc:
        return None
    desc = desc.strip()
    if desc.lower() in GENERIC_DESCRIPTIONS:
        return None
    if len(desc) < 20:
        return None
    return desc[0].upper() + desc[1:]


# ── Cache helpers ─────────────────────────────────────────────────────────────

def _load_cache(path: Path) -> dict:
    if path.exists():
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return {}


def _save_cache(cache: dict, path: Path) -> None:
    DATA_CACHE.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, separators=(",", ":"))
    tmp.replace(path)


# ── Wikidata query ─────────────────────────────────────────────────────────────

def _query_wikidata_batch(names: list[str]) -> dict:
    """Returns {name_lower: {"origin": str|None, "meaning": str|None}}"""
    values = " ".join(f'"{n}"@fr' for n in names)
    limit  = len(names) * 8

    sparql = f"""
SELECT ?label ?descFr ?descEn ?langLabel WHERE {{
  VALUES ?label {{ {values} }}
  VALUES ?nameType {{ wd:Q202444 wd:Q12308941 wd:Q11879590 wd:Q3409032 }}
  ?item rdfs:label ?label.
  ?item wdt:P31 ?nameType.
  OPTIONAL {{
    ?item schema:description ?descFr.
    FILTER(LANG(?descFr) = "fr")
  }}
  OPTIONAL {{
    ?item schema:description ?descEn.
    FILTER(LANG(?descEn) = "en")
  }}
  OPTIONAL {{
    ?item wdt:P407 ?lang.
    ?lang rdfs:label ?langLabel.
    FILTER(LANG(?langLabel) = "fr")
  }}
}}
LIMIT {limit}
"""
    last_err = None
    for delay in [0.0] + RETRY_DELAYS:
        if delay > 0:
            print(f"    ↺ retry in {delay:.0f}s …", end=" ", flush=True)
            time.sleep(delay)
        try:
            resp = requests.get(
                WIKIDATA_ENDPOINT,
                params={"query": sparql, "format": "json"},
                headers=WIKIDATA_HEADERS,
                timeout=60,
            )
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            last_err = e
            print(f"⚠ {e}", flush=True)
            continue

        results: dict[str, dict] = {}
        for binding in data.get("results", {}).get("bindings", []):
            label    = binding.get("label",     {}).get("value", "")
            desc_fr  = binding.get("descFr",    {}).get("value", "")
            desc_en  = binding.get("descEn",    {}).get("value", "")
            lang_fr  = binding.get("langLabel", {}).get("value", "").lower()

            if not label:
                continue
            key = label.lower()
            if key not in results:
                results[key] = {"origin": None, "meaning": None}
            entry = results[key]

            is_name_item = (
                "prénom" in desc_fr.lower()
                or "given name" in desc_en.lower()
                or "first name" in desc_en.lower()
            )

            if not entry["origin"]:
                if lang_fr and is_name_item and lang_fr in _P407_TO_ORIGIN:
                    entry["origin"] = _P407_TO_ORIGIN[lang_fr]
                elif desc_fr:
                    entry["origin"] = _detect_origin_fr(desc_fr)
                if not entry["origin"] and desc_en:
                    entry["origin"] = _detect_origin_en(desc_en)

            if not entry["meaning"] and desc_fr and is_name_item:
                entry["meaning"] = _extract_meaning(desc_fr)

        return results

    print(f"\n    ✗ Batch failed after all retries: {last_err}")
    return {}


# ── DB helpers ────────────────────────────────────────────────────────────────

def _ensure_origin_source_column(con: sqlite3.Connection) -> None:
    cols = {row[1] for row in con.execute("PRAGMA table_info(names)")}
    if "origin_source" not in cols:
        con.execute("ALTER TABLE names ADD COLUMN origin_source TEXT")
        con.commit()
        print("  + Added column origin_source")


def _fetch_targets(con: sqlite3.Connection, all_null: bool) -> list[str]:
    if all_null:
        rows = con.execute(
            "SELECT DISTINCT name FROM names WHERE origin IS NULL ORDER BY name"
        ).fetchall()
    else:
        rows = con.execute(
            """SELECT DISTINCT name FROM names
               WHERE origin IS NULL
               AND (popularity_rank_fr <= 5000 OR popularity_rank_us <= 5000)
               ORDER BY COALESCE(popularity_rank_fr, 99999)"""
        ).fetchall()
    return [r[0] for r in rows]


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all-null",  action="store_true",
                        help="Target ALL NULL-origin names (slow, ~41k)")
    parser.add_argument("--dry-run",   action="store_true",
                        help="Print results without writing to DB")
    args = parser.parse_args()

    if not DB_PATH.exists():
        raise SystemExit(f"DB not found: {DB_PATH}")

    con = sqlite3.connect(DB_PATH)
    _ensure_origin_source_column(con)

    targets = _fetch_targets(con, all_null=args.all_null)
    print(f"\n[Wikidata enrich] {len(targets):,} names to query "
          f"({'all NULL' if args.all_null else 'popularity top-5000'})\n")

    # Load enrich cache; import legacy wikidata hits only when origin was found
    # (don't import legacy null entries — we want to re-query those)
    enrich_cache = _load_cache(ENRICH_CACHE)
    legacy_cache = _load_cache(WIKIDATA_CACHE)
    imported = 0
    for k, v in legacy_cache.items():
        if k not in enrich_cache and v.get("origin"):
            enrich_cache[k] = v
            imported += 1
    if imported:
        print(f"  Imported {imported:,} hits from legacy wikidata cache")

    to_fetch = [n for n in targets if n.lower() not in enrich_cache]
    cache_hits = len(targets) - len(to_fetch)
    print(f"  Cache hits : {cache_hits:,}")
    print(f"  To fetch   : {len(to_fetch):,}\n")

    # Fetch missing from Wikidata
    total = len(to_fetch)
    for batch_idx, start in enumerate(range(0, total, BATCH_SIZE)):
        batch  = to_fetch[start: start + BATCH_SIZE]
        result = _query_wikidata_batch(batch)
        for name in batch:
            enrich_cache[name.lower()] = result.get(
                name.lower(), {"origin": None, "meaning": None}
            )
        progress = min(start + BATCH_SIZE, total)
        print(f"  Fetched {progress}/{total} …", end="\r", flush=True)

        if (batch_idx + 1) % CACHE_SAVE_EVERY == 0:
            _save_cache(enrich_cache, ENRICH_CACHE)

        time.sleep(BATCH_SLEEP)

    if total > 0:
        print()
        _save_cache(enrich_cache, ENRICH_CACHE)

    # Apply results to DB
    updated_origin  = 0
    updated_meaning = 0
    for name in targets:
        entry = enrich_cache.get(name.lower(), {})
        new_origin  = entry.get("origin")
        new_meaning = entry.get("meaning")

        if not new_origin and not new_meaning:
            continue

        if args.dry_run:
            if new_origin:
                print(f"  [DRY] {name} → {new_origin}")
            continue

        if new_origin:
            con.execute(
                "UPDATE names SET origin = ?, origin_source = 'wikidata' WHERE name = ? AND origin IS NULL",
                (new_origin, name),
            )
            updated_origin += 1

        if new_meaning:
            con.execute(
                "UPDATE names SET meaning = ? WHERE name = ? AND (meaning IS NULL OR meaning = '')",
                (new_meaning, name),
            )
            updated_meaning += 1

    if not args.dry_run:
        con.commit()

    con.close()

    if args.dry_run:
        print("\n[DRY-RUN] No changes written.")
    else:
        print(f"\n✓ Updated origins  : {updated_origin:,}")
        print(f"✓ Updated meanings : {updated_meaning:,}")

    # Coverage report
    con2 = sqlite3.connect(DB_PATH)
    total_rows   = con2.execute("SELECT COUNT(*) FROM names").fetchone()[0]
    with_origin  = con2.execute("SELECT COUNT(*) FROM names WHERE origin IS NOT NULL").fetchone()[0]
    still_null   = con2.execute("SELECT COUNT(*) FROM names WHERE origin IS NULL").fetchone()[0]
    top5k_null   = con2.execute(
        "SELECT COUNT(*) FROM names WHERE origin IS NULL AND (popularity_rank_fr <= 5000 OR popularity_rank_us <= 5000)"
    ).fetchone()[0]
    con2.close()

    pct = 100 * with_origin // total_rows
    print(f"\n── Coverage report ──────────────────────────────────")
    print(f"  Total names    : {total_rows:,}")
    print(f"  With origin    : {with_origin:,}  ({pct}%)")
    print(f"  Still NULL     : {still_null:,}")
    print(f"  NULL in top-5k : {top5k_null:,}")
    print()
    if top5k_null == 0:
        print("  ✓ Top-5000 fully enriched — run heuristic_origin.py for the long tail.")
    else:
        print("  ⚠  Run again or use --all-null for deeper coverage.")


if __name__ == "__main__":
    main()
