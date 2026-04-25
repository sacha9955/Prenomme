#!/usr/bin/env python3
from __future__ import annotations
"""
import_names.py — Generates Resources/names.sqlite from INSEE + SSA + Wikidata.

Steps:
    A) Parse INSEE prenoms-2024-nat.csv  (threshold ≥ 20 over 2015-2024)
    B) Parse SSA yob*.txt               (2015-2024, threshold ≥ 20)
    C) Enrich with Wikidata SPARQL       (origin + meaning, cached JSON)
    D) Apply data/manual_origins.csv     (optional override)
    E) Compute syllables (pyphen) + French IPA phonetic
    F) Classify themes from descriptions
    G) Write SQLite + 5 indexes + VACUUM

Usage:
    pip install -r scripts/requirements.txt
    python3 scripts/import_names.py
    python3 scripts/import_names.py --threshold 10 --no-wikidata
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import time
from collections import defaultdict
from pathlib import Path

from typing import Optional

import requests

# ── Paths ───────────────────────────────────────────────────────────────────
ROOT         = Path(__file__).parent.parent
DATA_RAW     = ROOT / "data" / "raw"
DATA_CACHE   = ROOT / "data" / "cache"
OUTPUT_DB    = ROOT / "Resources" / "names.sqlite"
INSEE_FILE   = DATA_RAW / "prenoms-2024-nat.csv"
SSA_DIR      = DATA_RAW / "ssa_us"
WIKIDATA_CACHE  = DATA_CACHE / "wikidata_cache.json"
MANUAL_ORIGINS  = DATA_RAW / "manual_origins.csv"

# ── Thresholds & config ──────────────────────────────────────────────────────
INSEE_THRESHOLD   = 20
SSA_THRESHOLD     = 20
SSA_YEARS         = range(2015, 2025)
WIKIDATA_BATCH    = 100
WIKIDATA_SLEEP    = 1.2   # seconds between batches (Wikidata rate limit)
WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
WIKIDATA_HEADERS  = {
    "User-Agent": "PrenommeApp/1.0 (github.com/prenomme) import_names.py",
    "Accept": "application/sparql-results+json",
}

# ── Origin detection from French Wikidata descriptions ──────────────────────
ORIGIN_KEYWORDS = {
    "hébraïque": "Hébreu",
    "hébreu":    "Hébreu",
    "latin":     "Latin",
    "latine":    "Latin",
    "latinisé":  "Latin",
    "grec":      "Grec",
    "grecque":   "Grec",
    "germanique": "Germanique",
    "vieux haut-allemand": "Germanique",
    "vieux saxon": "Germanique",
    "anglais":   "Anglais",
    "anglaise":  "Anglais",
    "arabe":     "Arabe",
    "breton":    "Breton",
    "bretonne":  "Breton",
    "nordique":  "Nordique",
    "norrois":   "Nordique",
    "vieux norrois": "Nordique",
    "scandinave": "Nordique",
    "japonais":  "Japonais",
    "japonaise": "Japonais",
    "persan":    "Perse",
    "perse":     "Perse",
    "sanskrit":  "Sanskrit",
    "sanscrit":  "Sanskrit",
    "védique":   "Sanskrit",
    "celtique":  "Celtique",
    "irlandais": "Irlandais",
    "irlandaise": "Irlandais",
    "gallois":   "Gallois",
    "galloise":  "Gallois",
    "espagnol":  "Espagnol",
    "espagnole": "Espagnol",
    "basque":    "Basque",
    "occitan":   "Occitan",
    "occitane":  "Occitan",
    "normand":   "Normand",
    "normande":  "Normand",
    "slave":     "Slave",
    "slavon":    "Slave",
    "ukrainien": "Ukrainien",
    "ukrainienne": "Ukrainien",
    "chinois":   "Chinois",
    "chinoise":  "Chinois",
    "coréen":    "Coréen",
    "coréenne":  "Coréen",
    "swahili":   "Swahili",
    "yoruba":    "Yoruba",
    "igbo":      "Igbo",
    "akan":      "Akan",
    "araméen":   "Araméen",
    "araméenne": "Araméen",
}

ORIGIN_LOCALE = {
    "Hébreu":      "he-IL",
    "Latin":       "la",
    "Grec":        "el-GR",
    "Germanique":  "de-DE",
    "Anglais":     "en-GB",
    "Arabe":       "ar-SA",
    "Breton":      "br",
    "Nordique":    "sv-SE",
    "Japonais":    "ja-JP",
    "Perse":       "fa-IR",
    "Sanskrit":    "hi-IN",
    "Celtique":    "ga-IE",
    "Irlandais":   "ga-IE",
    "Gallois":     "cy-GB",
    "Espagnol":    "es-ES",
    "Basque":      "eu-ES",
    "Occitan":     "oc",
    "Normand":     "fr-FR",
    "Slave":       "ru-RU",
    "Ukrainien":   "uk-UA",
    "Chinois":     "zh-CN",
    "Coréen":      "ko-KR",
    "Swahili":     "sw",
    "Yoruba":      "yo",
    "Igbo":        "ig",
    "Akan":        "ak",
    "Araméen":     "ar-SY",
}

THEME_KEYWORDS = {
    "nature":     ["nature", "forêt", "arbre", "fleur", "rivière", "mer", "soleil", "lune",
                   "étoile", "vent", "terre", "montagne", "pierre", "feu", "eau"],
    "mythologie": ["dieu", "déesse", "mythologie", "mythe", "olympe", "héros", "légende",
                   "divin", "sacré", "nymphe", "titan"],
    "force":      ["force", "fort", "puissant", "courage", "brave", "guerrier", "combat",
                   "vaillant", "victoire", "conquête", "champion"],
    "lumière":    ["lumière", "brillant", "éclat", "clarté", "lumineux", "radieux",
                   "brillante", "solaire", "resplendissant"],
    "amour":      ["amour", "amoureux", "chéri", "adoré", "doux", "tendre", "grâce",
                   "belle", "beauté", "désir"],
    "sagesse":    ["sage", "sagesse", "intelligence", "connaissance", "esprit", "pensée",
                   "raison", "philosophie"],
    "noblesse":   ["noble", "roi", "reine", "prince", "princesse", "seigneur",
                   "aristocrate", "royal", "majesté"],
    "religion":   ["saint", "béni", "divin", "sacré", "dieu", "bienheureux",
                   "bénie", "prophète", "ange", "église"],
    "mer":        ["mer", "océan", "eau", "marin", "vague", "plage", "côte", "navigation"],
}


# ── Step A: Parse INSEE ──────────────────────────────────────────────────────

def normalize_name(raw: str) -> str:
    """JEAN-BAPTISTE → Jean-Baptiste (handles hyphens and spaces)."""
    raw = raw.strip()
    # .title() capitalises after non-alpha chars including hyphen
    normalized = raw.title()
    # Fix apostrophe: D'André → D'André (already handled by title())
    return normalized


def parse_insee(threshold: int) -> dict:
    """
    Returns {(name_display, gender): total_fr_count}
    Only includes names with sum(2015-2024) >= threshold.
    Skips the XXXX aggregate row.
    """
    print(f"[A] Parsing INSEE ({INSEE_FILE.name}) …")
    if not INSEE_FILE.exists():
        sys.exit(f"Error: {INSEE_FILE} not found.")

    # Accumulate counts per (raw_name, sexe) across all years 2015-2024
    raw_counts: dict[tuple, int] = defaultdict(int)

    with open(INSEE_FILE, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("sexe"):
                continue
            parts = line.split(";")
            if len(parts) != 4:
                continue
            sexe, prenom, periode, valeur = parts
            if prenom == "XXXX" or valeur == "XXXX":
                continue
            try:
                year = int(periode)
                count = int(valeur)
            except ValueError:
                continue
            if year not in range(2015, 2025):
                continue
            raw_counts[(prenom, sexe)] += count

    # Apply threshold and build result
    result: dict[tuple[str, str], int] = {}
    for (prenom, sexe), total in raw_counts.items():
        if total < threshold:
            continue
        name = normalize_name(prenom)
        gender = "male" if sexe == "1" else "female"
        key = (name, gender)
        result[key] = result.get(key, 0) + total

    # Merge male+female into unisex when both genders exist with significant counts
    merged: dict[tuple[str, str], int] = {}
    name_genders: dict[str, list] = defaultdict(list)
    for (name, gender), count in result.items():
        name_genders[name].append((gender, count))

    for name, gender_counts in name_genders.items():
        if len(gender_counts) == 1:
            gender, count = gender_counts[0]
            merged[(name, gender)] = count
        else:
            # Both genders — keep both separate (unisex is handled differently)
            total = sum(c for _, c in gender_counts)
            counts = {g: c for g, c in gender_counts}
            male_count = counts.get("male", 0)
            female_count = counts.get("female", 0)
            # If one gender is < 10% of the other, keep dominant only
            if male_count > female_count * 10:
                merged[(name, "male")] = total
            elif female_count > male_count * 10:
                merged[(name, "female")] = total
            else:
                # True unisex
                merged[(name, "unisex")] = total

    print(f"    → {len(merged):,} name+gender pairs after threshold ≥ {threshold}")
    return merged


# ── Step B: Parse SSA ────────────────────────────────────────────────────────

def parse_ssa(threshold: int) -> dict:
    """
    Returns {(name_display, gender): total_us_count}
    Only includes names with sum(2015-2024) >= threshold.
    """
    print(f"[B] Parsing SSA ({SSA_DIR.name}/) …")
    if not SSA_DIR.exists():
        sys.exit(f"Error: {SSA_DIR} not found.")

    raw_counts: dict[tuple, int] = defaultdict(int)

    for year in SSA_YEARS:
        yob_file = SSA_DIR / f"yob{year}.txt"
        if not yob_file.exists():
            print(f"    ⚠ Missing {yob_file.name}, skipping")
            continue
        with open(yob_file, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                parts = line.split(",")
                if len(parts) != 3:
                    continue
                name, sex, count_str = parts
                try:
                    count = int(count_str)
                except ValueError:
                    continue
                gender = "male" if sex == "M" else "female"
                raw_counts[(name, gender)] += count

    result: dict[tuple[str, str], int] = {}
    for (name, gender), total in raw_counts.items():
        if total >= threshold:
            result[(name, gender)] = total

    print(f"    → {len(result):,} name+gender pairs after threshold ≥ {threshold}")
    return result


# ── Step C: Wikidata enrichment ──────────────────────────────────────────────

# P407 language → origin (Wikidata language item labels in French)
_P407_TO_ORIGIN = {
    "hébreu":           "Hébreu",
    "hébreu biblique":  "Hébreu",
    "araméen":          "Araméen",
    "latin":            "Latin",
    "latin classique":  "Latin",
    "grec ancien":      "Grec",
    "grec":             "Grec",
    "vieux haut-allemand": "Germanique",
    "vieux saxon":      "Germanique",
    "allemand":         "Germanique",
    "anglais":          "Anglais",
    "vieil anglais":    "Anglais",
    "arabe":            "Arabe",
    "arabe classique":  "Arabe",
    "breton":           "Breton",
    "vieux norrois":    "Nordique",
    "norrois":          "Nordique",
    "islandais":        "Nordique",
    "japonais":         "Japonais",
    "persan":           "Perse",
    "moyen persan":     "Perse",
    "sanskrit":         "Sanskrit",
    "irlandais médiéval": "Irlandais",
    "vieil irlandais":  "Irlandais",
    "irlandais":        "Irlandais",
    "gallois":          "Gallois",
    "espagnol":         "Espagnol",
    "basque":           "Basque",
    "occitan":          "Occitan",
    "russe":            "Slave",
    "polonais":         "Slave",
    "ukrainien":        "Ukrainien",
    "chinois":          "Chinois",
    "coréen":           "Coréen",
    "swahili":          "Swahili",
    "yoruba":           "Yoruba",
    "igbo":             "Igbo",
}

# English description keywords → origin (Wikidata EN descriptions)
_EN_ORIGIN_KEYWORDS = {
    "hebrew":     "Hébreu",
    "aramaic":    "Araméen",
    "latin":      "Latin",
    "greek":      "Grec",
    "germanic":   "Germanique",
    "old high german": "Germanique",
    "english":    "Anglais",
    "old english": "Anglais",
    "arabic":     "Arabe",
    "breton":     "Breton",
    "old norse":  "Nordique",
    "norse":      "Nordique",
    "japanese":   "Japonais",
    "persian":    "Perse",
    "sanskrit":   "Sanskrit",
    "irish":      "Irlandais",
    "welsh":      "Gallois",
    "spanish":    "Espagnol",
    "basque":     "Basque",
    "occitan":    "Occitan",
    "slavic":     "Slave",
    "ukrainian":  "Ukrainien",
    "chinese":    "Chinois",
    "korean":     "Coréen",
    "swahili":    "Swahili",
    "yoruba":     "Yoruba",
    "igbo":       "Igbo",
}


def _query_wikidata_batch(names):  # type: (list) -> dict
    """
    Returns {name_lower: {"origin": str|None, "meaning": str|None}}
    Fetches French/English descriptions + P407 (language) to infer origin.
    """
    # Only use French labels — EN labels would multiply results unnecessarily
    values = " ".join(f'"{n}"@fr' for n in names)
    limit  = len(names) * 8  # each name may have multiple items + languages

    # Q202444=given name  Q12308941=male given name  Q11879590=female given name  Q3409032=unisex given name
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
    try:
        resp = requests.get(
            WIKIDATA_ENDPOINT,
            params={"query": sparql, "format": "json"},
            headers=WIKIDATA_HEADERS,
            timeout=45,
        )
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        print(f"\n    ⚠ Wikidata error: {e}")
        return {}

    results: dict[str, dict] = {}
    for binding in data.get("results", {}).get("bindings", []):
        label     = binding.get("label",     {}).get("value", "")
        desc_fr   = binding.get("descFr",    {}).get("value", "")
        desc_en   = binding.get("descEn",    {}).get("value", "")
        lang_fr   = binding.get("langLabel", {}).get("value", "").lower()

        if not label:
            continue
        key = label.lower()
        if key not in results:
            results[key] = {"origin": None, "meaning": None}
        entry = results[key]

        # Only use data from items that are actually given names
        is_name_item = (
            "prénom" in desc_fr.lower()
            or "given name" in desc_en.lower()
            or "first name" in desc_en.lower()
        )

        # Origin: P407 language > French description > English description
        if not entry["origin"]:
            if lang_fr and is_name_item and lang_fr in _P407_TO_ORIGIN:
                entry["origin"] = _P407_TO_ORIGIN[lang_fr]
            elif desc_fr:
                entry["origin"] = _detect_origin_fr(desc_fr)
            if not entry["origin"] and desc_en:
                entry["origin"] = _detect_origin_en(desc_en)

        # Meaning: French description only, and only from name items
        if not entry["meaning"] and desc_fr and is_name_item:
            entry["meaning"] = _extract_meaning(desc_fr)

    return results


def _detect_origin_fr(description: str) -> Optional[str]:
    desc_lower = description.lower()
    for keyword, origin in ORIGIN_KEYWORDS.items():
        if keyword in desc_lower:
            return origin
    return None


def _detect_origin_en(description: str) -> Optional[str]:
    # Detect non-Latin scripts in parenthetical native-script annotations like "Ibrahim (إبراهيم)"
    import re as _re
    if _re.search(r'[؀-ۿ]', description):   # Arabic script
        return "Arabe"
    if _re.search(r'[֐-׿]', description):   # Hebrew script
        return "Hébreu"
    if _re.search(r'[一-鿿぀-ゟ゠-ヿ]', description):  # CJK/Kana
        return "Japonais"
    if _re.search(r'[ऀ-ॿ]', description):   # Devanagari
        return "Sanskrit"
    desc_lower = description.lower()
    for keyword, origin in _EN_ORIGIN_KEYWORDS.items():
        if keyword in desc_lower:
            return origin
    return None


def _extract_meaning(description: str) -> Optional[str]:
    """Return description as meaning when it's more than a bare classification."""
    if not description:
        return None
    desc = description.strip()
    generic = {
        "prénom", "prénom masculin", "prénom féminin", "prénom mixte",
        "prénom masculin français", "prénom féminin français",
        "prénom épicène", "prénom épicène français",
        "male given name", "female given name", "unisex given name",
    }
    if desc.lower() in generic:
        return None
    if len(desc) < 20:
        return None
    return desc[0].upper() + desc[1:]


def load_wikidata_cache() -> dict:
    if WIKIDATA_CACHE.exists():
        with open(WIKIDATA_CACHE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_wikidata_cache(cache: dict) -> None:
    DATA_CACHE.mkdir(parents=True, exist_ok=True)
    tmp = WIKIDATA_CACHE.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, separators=(",", ":"))
    tmp.replace(WIKIDATA_CACHE)


CACHE_SAVE_INTERVAL = 50   # save every N batches to preserve progress


def enrich_wikidata(all_names, skip=False):  # type: (list, bool) -> dict
    """
    Returns {name_lower: {"origin": str|None, "meaning": str|None}}
    Saves cache every CACHE_SAVE_INTERVAL batches (resume-safe).
    """
    if skip:
        print("[C] Wikidata skipped (--no-wikidata)")
        return {}

    print("[C] Enriching with Wikidata …")
    cache = load_wikidata_cache()

    to_fetch = [n for n in all_names if n.lower() not in cache]
    total    = len(to_fetch)
    print(f"    Cache hits: {len(cache):,} / {len(all_names):,} — fetching {total:,}")

    for batch_idx, i in enumerate(range(0, total, WIKIDATA_BATCH)):
        batch  = to_fetch[i : i + WIKIDATA_BATCH]
        result = _query_wikidata_batch(batch)
        for name in batch:
            cache[name.lower()] = result.get(name.lower(), {"origin": None, "meaning": None})

        progress = min(i + WIKIDATA_BATCH, total)
        print(f"    {progress}/{total} fetched …", end="\r")

        if (batch_idx + 1) % CACHE_SAVE_INTERVAL == 0:
            save_wikidata_cache(cache)

        time.sleep(WIKIDATA_SLEEP)

    print()
    save_wikidata_cache(cache)
    print(f"    Cache saved → {WIKIDATA_CACHE}")
    return cache


# ── Step D: Manual origins ───────────────────────────────────────────────────

def load_manual_origins() -> dict[str, dict]:
    """
    Returns {name_lower: {"origin": str, "meaning": str|None}}
    CSV format: name,origin,meaning  (meaning optional)
    """
    if not MANUAL_ORIGINS.exists():
        return {}

    print(f"[D] Loading manual origins from {MANUAL_ORIGINS.name} …")
    overrides: dict[str, dict] = {}

    with open(MANUAL_ORIGINS, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or line.startswith("name"):
                continue
            parts = line.split(",", 2)
            name = parts[0].strip().lower()
            origin = parts[1].strip() if len(parts) > 1 else ""
            meaning = parts[2].strip() if len(parts) > 2 else None
            if name and origin:
                overrides[name] = {"origin": origin, "meaning": meaning or None}

    print(f"    → {len(overrides):,} manual overrides loaded")
    return overrides


# ── Step E: Syllables + phonetic ─────────────────────────────────────────────

def _count_vowel_groups(name: str) -> int:
    """Fallback syllable counter (vowel group detection)."""
    vowels = set("aeiouyàáâãäåèéêëìíîïòóôõöùúûüý")
    count = 0
    in_vowel = False
    for ch in name.lower():
        if ch in vowels:
            if not in_vowel:
                count += 1
                in_vowel = True
        else:
            in_vowel = False
    return max(1, count)


def _make_syllable_counter():
    """Returns a syllable-counting function, using pyphen if available."""
    try:
        import pyphen
        dic_fr = pyphen.Pyphen(lang="fr_FR")
        dic_en = pyphen.Pyphen(lang="en_US")

        def count_syllables(name: str, is_french: bool = True) -> int:
            try:
                dic = dic_fr if is_french else dic_en
                hyphenated = dic.inserted(name.lower())
                return max(1, hyphenated.count("-") + 1)
            except Exception:
                return _count_vowel_groups(name)

        print("    pyphen loaded (fr_FR + en_US)")
        return count_syllables

    except ImportError:
        print("    ⚠ pyphen not available, using vowel-group fallback")
        return lambda name, is_french=True: _count_vowel_groups(name)


# French IPA rule-based conversion (approximate)
_FR_IPA_RULES = [
    # Order matters — longest match first
    (r"eau",    "o"),
    (r"oeu",    "ø"),
    (r"œu",     "ø"),
    (r"oeil",   "œj"),
    (r"eil",    "ɛj"),
    (r"aille",  "aj"),
    (r"aille",  "aj"),
    (r"eille",  "ɛj"),
    (r"ouille", "uj"),
    (r"ille",   "ij"),
    (r"gn",     "ɲ"),
    (r"ch",     "ʃ"),
    (r"ph",     "f"),
    (r"qu",     "k"),
    (r"ck",     "k"),
    (r"ou",     "u"),
    (r"oi",     "wa"),
    (r"oy",     "waj"),
    (r"ai",     "ɛ"),
    (r"ei",     "ɛ"),
    (r"au",     "o"),
    (r"an",     "ɑ̃"),
    (r"am",     "ɑ̃"),
    (r"en",     "ɑ̃"),
    (r"em",     "ɑ̃"),
    (r"in",     "ɛ̃"),
    (r"im",     "ɛ̃"),
    (r"ain",    "ɛ̃"),
    (r"ein",    "ɛ̃"),
    (r"un",     "œ̃"),
    (r"um",     "œ̃"),
    (r"on",     "ɔ̃"),
    (r"om",     "ɔ̃"),
    (r"eu",     "ø"),
    (r"é",      "e"),
    (r"è",      "ɛ"),
    (r"ê",      "ɛ"),
    (r"ë",      "ɛ"),
    (r"â",      "ɑ"),
    (r"à",      "a"),
    (r"î",      "i"),
    (r"ï",      "i"),
    (r"ô",      "o"),
    (r"ù",      "y"),
    (r"û",      "y"),
    (r"ü",      "y"),
    (r"ç",      "s"),
    (r"x",      "ks"),
    (r"th",     "t"),
    (r"ge",     "ʒ"),
    (r"gi",     "ʒ"),
    (r"g",      "ɡ"),
    (r"j",      "ʒ"),
    (r"r",      "ʁ"),
    (r"y",      "i"),
    (r"e$",     ""),    # silent final e
    (r"s$",     ""),    # silent final s (most of the time)
    (r"t$",     ""),    # silent final t
    (r"d$",     ""),    # silent final d
]

# Precompile rules
_COMPILED_RULES = [(re.compile(pat), rep) for pat, rep in _FR_IPA_RULES]


def french_ipa(name: str) -> str:
    """Approximate French IPA for a given name."""
    s = name.lower()
    for pattern, replacement in _COMPILED_RULES:
        s = pattern.sub(replacement, s)
    return f"/{s}/"


# ── Step F: Theme classification ─────────────────────────────────────────────

def classify_themes(meaning):  # type: (Optional[str]) -> list
    if not meaning:
        return []
    text = meaning.lower()
    found = []
    for theme, keywords in THEME_KEYWORDS.items():
        if any(kw in text for kw in keywords):
            found.append(theme)
    return found


# ── Step G: Write SQLite ─────────────────────────────────────────────────────

CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS names (
    id                  INTEGER PRIMARY KEY,
    name                TEXT NOT NULL,
    gender              TEXT CHECK(gender IN ('male','female','unisex')),
    origin              TEXT,
    origin_locale       TEXT,
    meaning             TEXT,
    syllables           INTEGER,
    popularity_rank_fr  INTEGER,
    popularity_rank_us  INTEGER,
    themes              TEXT,
    phonetic            TEXT
);
"""

CREATE_INDEXES = [
    "CREATE INDEX IF NOT EXISTS idx_name   ON names(name);",
    "CREATE INDEX IF NOT EXISTS idx_gender ON names(gender);",
    "CREATE INDEX IF NOT EXISTS idx_origin ON names(origin);",
    "CREATE INDEX IF NOT EXISTS idx_pop_fr ON names(popularity_rank_fr);",
    "CREATE INDEX IF NOT EXISTS idx_pop_us ON names(popularity_rank_us);",
]

INSERT_SQL = """
INSERT INTO names
    (name, gender, origin, origin_locale, meaning, syllables,
     popularity_rank_fr, popularity_rank_us, themes, phonetic)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""


def build_database(rows):  # type: (list) -> None
    OUTPUT_DB.parent.mkdir(parents=True, exist_ok=True)
    if OUTPUT_DB.exists():
        OUTPUT_DB.unlink()

    con = sqlite3.connect(OUTPUT_DB)
    cur = con.cursor()
    cur.executescript(CREATE_TABLE)

    for row in rows:
        cur.execute(INSERT_SQL, (
            row["name"],
            row["gender"],
            row["origin"],
            row["origin_locale"],
            row["meaning"],
            row["syllables"],
            row["rank_fr"],
            row["rank_us"],
            json.dumps(row["themes"], ensure_ascii=False) if row["themes"] else None,
            row["phonetic"],
        ))

    for idx_sql in CREATE_INDEXES:
        cur.executescript(idx_sql)

    cur.executescript("VACUUM;")
    con.commit()
    con.close()

    size_mb = OUTPUT_DB.stat().st_size / 1_048_576
    print(f"[G] Wrote {len(rows):,} rows → {OUTPUT_DB}  ({size_mb:.1f} MB)")


# ── Main orchestration ───────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Generate names.sqlite")
    parser.add_argument("--threshold", type=int, default=INSEE_THRESHOLD,
                        help=f"Min name count 2015-2024 (default: {INSEE_THRESHOLD})")
    parser.add_argument("--no-wikidata", action="store_true",
                        help="Skip Wikidata enrichment (uses cache if available)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Parse + enrich but do not write DB")
    args = parser.parse_args()

    # ── A: INSEE ──────────────────────────────────────────────────────────
    insee_data = parse_insee(args.threshold)

    # ── B: SSA ────────────────────────────────────────────────────────────
    ssa_data = parse_ssa(args.threshold)

    # ── Merge INSEE + SSA ─────────────────────────────────────────────────
    # Key: (display_name, gender). INSEE is primary; SSA adds US-only names.
    print("[merge] Combining INSEE and SSA …")

    # Build unified name set with source tracking
    all_entries: dict[tuple[str, str], dict] = {}

    # INSEE first
    for (name, gender), count_fr in insee_data.items():
        all_entries[(name, gender)] = {"count_fr": count_fr, "count_us": 0}

    # SSA — add US count if entry exists, else add new entry
    for (name, gender), count_us in ssa_data.items():
        # Try to find matching entry (case-insensitive)
        matched = False
        for (existing_name, existing_gender) in list(all_entries.keys()):
            if existing_name.lower() == name.lower() and existing_gender == gender:
                all_entries[(existing_name, existing_gender)]["count_us"] = count_us
                matched = True
                break
        if not matched:
            all_entries[(name, gender)] = {"count_fr": 0, "count_us": count_us}

    print(f"    → {len(all_entries):,} unique name+gender pairs total")

    # ── C: Wikidata ───────────────────────────────────────────────────────
    unique_names = list({name for (name, _) in all_entries})
    wikidata = enrich_wikidata(unique_names, skip=args.no_wikidata)

    # ── D: Manual overrides ───────────────────────────────────────────────
    manual = load_manual_origins()

    # ── E: Syllables + phonetic ───────────────────────────────────────────
    print("[E] Computing syllables + phonetics …")
    count_syllables = _make_syllable_counter()

    # ── FR and US rank assignment ─────────────────────────────────────────
    # Rank by FR count descending, US separately
    fr_ranked = sorted(
        [(name, gender) for (name, gender), d in all_entries.items() if d["count_fr"] > 0],
        key=lambda k: all_entries[k]["count_fr"],
        reverse=True,
    )
    fr_rank_map = {key: rank + 1 for rank, key in enumerate(fr_ranked)}

    us_ranked = sorted(
        [(name, gender) for (name, gender), d in all_entries.items() if d["count_us"] > 0],
        key=lambda k: all_entries[k]["count_us"],
        reverse=True,
    )
    us_rank_map = {key: rank + 1 for rank, key in enumerate(us_ranked)}

    # ── F + assemble rows ─────────────────────────────────────────────────
    print("[F] Classifying themes + assembling rows …")
    rows = []  # type: list

    for (name, gender), counts in all_entries.items():
        key = name.lower()

        # Origin + meaning: manual > wikidata
        if key in manual:
            origin  = manual[key]["origin"]
            meaning = manual[key]["meaning"]
        else:
            wiki    = wikidata.get(key, {})
            origin  = wiki.get("origin")
            meaning = wiki.get("meaning")

        origin_locale = ORIGIN_LOCALE.get(origin) if origin else None
        is_french = origin not in {"Japonais", "Chinois", "Coréen", "Arabe",
                                   "Swahili", "Yoruba", "Igbo", "Akan"}

        syllables = count_syllables(name, is_french=is_french)
        phonetic  = french_ipa(name)
        themes    = classify_themes(meaning)

        rows.append({
            "name":         name,
            "gender":       gender,
            "origin":       origin,
            "origin_locale": origin_locale,
            "meaning":      meaning,
            "syllables":    syllables,
            "rank_fr":      fr_rank_map.get((name, gender)),
            "rank_us":      us_rank_map.get((name, gender)),
            "themes":       themes,
            "phonetic":     phonetic,
        })

    # Sort by FR rank then name for stable insertion order
    rows.sort(key=lambda r: (r["rank_fr"] or 999_999, r["name"]))

    # ── G: Write SQLite ───────────────────────────────────────────────────
    if args.dry_run:
        print(f"[G] Dry run — {len(rows):,} rows prepared, DB not written.")
        _print_stats(rows)
        return

    build_database(rows)
    _print_stats(rows)


def _print_stats(rows):  # type: (list) -> None
    total = len(rows)
    with_origin  = sum(1 for r in rows if r["origin"])
    with_meaning = sum(1 for r in rows if r["meaning"])
    with_rank_fr = sum(1 for r in rows if r["rank_fr"])
    with_rank_us = sum(1 for r in rows if r["rank_us"])
    genders = {}
    for r in rows:
        genders[r["gender"]] = genders.get(r["gender"], 0) + 1

    print("\n── Stats ────────────────────────────────────────")
    print(f"  Total names    : {total:,}")
    print(f"  With origin    : {with_origin:,}  ({100*with_origin//total}%)")
    print(f"  With meaning   : {with_meaning:,}  ({100*with_meaning//total}%)")
    print(f"  With FR rank   : {with_rank_fr:,}  ({100*with_rank_fr//total}%)")
    print(f"  With US rank   : {with_rank_us:,}  ({100*with_rank_us//total}%)")
    for g, c in sorted(genders.items()):
        print(f"  {g:10s}   : {c:,}")
    print("─────────────────────────────────────────────────")


if __name__ == "__main__":
    main()
