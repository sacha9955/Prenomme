#!/usr/bin/env python3
"""
enrich_top1000.py — Génère l'étymologie des 1000 prénoms les plus populaires sans étymologie.

Usage:
    ANTHROPIC_API_KEY=sk-... python3 Scripts/enrich_top1000.py
    python3 Scripts/enrich_top1000.py --dry-run
    python3 Scripts/enrich_top1000.py --estimate-only
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import sys
import time
from pathlib import Path

ROOT      = Path(__file__).parent.parent
DB_PATH   = ROOT / "Resources" / "names.sqlite"
DB_BACKUP = ROOT / "Resources" / "names_before_top1000.sqlite"
CACHE_PATH = ROOT / "data" / "cache" / "top1000_etymology_cache.json"

PRICE_INPUT_PER_M  = 0.80
PRICE_OUTPUT_PER_M = 4.00
EUR_PER_USD        = 0.92

BATCH_SIZE = 25
TARGET     = 1000

SYSTEM_PROMPT = (
    "Tu es un expert en onomastique (étude des prénoms). "
    "Tu génères des étymologies courtes et précises en français pour une application mobile iOS. "
    "Chaque étymologie fait 2 à 3 phrases maximum. Elle décrit l'origine linguistique, "
    "la racine étymologique, et le sens du prénom. Ton style est factuel et accessible."
)


def build_prompt(items: list[dict]) -> str:
    lines = []
    for item in items:
        parts = []
        if item.get("origin") and item["origin"] not in ("Autre", ""):
            parts.append(f"origine: {item['origin']}")
        gender_fr = {"male": "masculin", "female": "féminin", "unisex": "épicène"}.get(item.get("gender", ""), "")
        if gender_fr:
            parts.append(f"genre: {gender_fr}")
        info = f" ({', '.join(parts)})" if parts else ""
        lines.append(f"- {item['name']}{info}")
    names_block = "\n".join(lines)
    return (
        "Pour chacun des prénoms suivants, génère une étymologie courte (2-3 phrases) en français.\n\n"
        "Format de réponse STRICT : une ligne par prénom, format \"NOM: étymologie\"\n"
        "Ne saute pas de ligne entre les prénoms. Ne numérote pas.\n\n"
        f"Prénoms :\n{names_block}"
    )


def load_cache() -> dict[str, str]:
    if CACHE_PATH.exists():
        with CACHE_PATH.open(encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_cache(cache: dict[str, str]) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CACHE_PATH.open("w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)


def generate_batch(client, items: list[dict]) -> dict[str, str] | None:
    prompt = build_prompt(items)
    for attempt in range(4):
        if attempt > 0:
            delay = [5.0, 15.0, 45.0][attempt - 1]
            print(f"    ↺ retry {attempt}/3 dans {delay}s…", flush=True)
            time.sleep(delay)
        try:
            response = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=len(items) * 100,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = response.content[0].text.strip()
            result: dict[str, str] = {}
            for line in raw.splitlines():
                line = line.strip()
                if not line or ": " not in line:
                    continue
                name_part, etymology = line.split(": ", 1)
                clean = name_part.lstrip("- ").strip()
                if etymology.strip():
                    result[clean] = etymology.strip()
            found = sum(1 for item in items if item["name"] in result)
            if found < len(items) // 2:
                print(f"    ⚠ réponse partielle ({found}/{len(items)}) — retry", flush=True)
                continue
            return result
        except Exception as exc:
            if "rate_limit" in str(exc).lower() or "429" in str(exc):
                continue
            print(f"    ✗ erreur : {exc}", flush=True)
            return None
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run",       action="store_true")
    parser.add_argument("--estimate-only", action="store_true")
    parser.add_argument("--target",        type=int, default=TARGET, help=f"Nombre de prénoms cibles (défaut {TARGET})")
    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key and not args.estimate_only:
        print("❌  ANTHROPIC_API_KEY non définie.")
        print("    Lance avec : ANTHROPIC_API_KEY=sk-... python3 Scripts/enrich_top1000.py")
        sys.exit(1)

    if not DB_PATH.exists():
        raise SystemExit(f"❌  DB introuvable : {DB_PATH}")

    con = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    rows = con.execute("""
        SELECT name, gender, origin FROM names
        WHERE (etymology IS NULL OR etymology = '')
        ORDER BY
            COALESCE(popularity_rank_fr, 99999),
            COALESCE(popularity_rank_us, 99999),
            name
        LIMIT ?
    """, (args.target,)).fetchall()
    con.close()

    all_items = [{"name": r[0], "gender": r[1], "origin": r[2]} for r in rows]
    total = len(all_items)

    n_batches = (total + BATCH_SIZE - 1) // BATCH_SIZE
    input_tok  = n_batches * (400 + BATCH_SIZE * 15)
    output_tok = n_batches * (BATCH_SIZE * 80)
    cost_usd   = (input_tok * PRICE_INPUT_PER_M + output_tok * PRICE_OUTPUT_PER_M) / 1_000_000
    print(f"\n{'─'*60}")
    print(f"  Prénoms à traiter  : {total}")
    print(f"  Batches            : {n_batches}  (taille {BATCH_SIZE})")
    print(f"  Coût estimé        : ${cost_usd:.3f}  (≈ {cost_usd * EUR_PER_USD:.2f}€)")
    print(f"{'─'*60}\n")

    if args.estimate_only:
        return

    cache = load_cache()
    cached = sum(1 for item in all_items if item["name"] in cache)
    to_fetch = [item for item in all_items if item["name"] not in cache]
    print(f"  Cache hits    : {cached}")
    print(f"  À appeler API : {len(to_fetch)}\n")

    if args.dry_run:
        to_fetch = to_fetch[:BATCH_SIZE]

    import anthropic
    client = anthropic.Anthropic(api_key=api_key)

    batches = [to_fetch[i:i + BATCH_SIZE] for i in range(0, len(to_fetch), BATCH_SIZE)]
    total_cost = 0.0

    for idx, batch in enumerate(batches, 1):
        print(f"  Batch {idx:>3}/{len(batches)}  ({len(batch)} prénoms)  — {total_cost * EUR_PER_USD:.3f}€", end="  ", flush=True)
        result = generate_batch(client, batch)
        if result is None:
            print("SKIP")
            continue
        cache.update(result)
        save_cache(cache)
        batch_cost = ((400 + len(batch) * 15) * PRICE_INPUT_PER_M + (len(batch) * 80) * PRICE_OUTPUT_PER_M) / 1_000_000
        total_cost += batch_cost
        print(f"✓  ({len(result)} étymologies)")
        if args.dry_run:
            print("\n  Exemples :")
            for name, etym in list(result.items())[:3]:
                print(f"    {name}: {etym[:90]}{'…' if len(etym) > 90 else ''}")
            print("\n[DRY-RUN] Aucune écriture DB.")
            return
        time.sleep(0.8)

    # Écriture en base
    total_cached = len(cache)
    print(f"\n  Cache total : {total_cached} étymologies")
    if total_cached == 0:
        print("  Rien à écrire.")
        return

    shutil.copy2(DB_PATH, DB_BACKUP)
    print(f"✓ Backup : {DB_BACKUP.name}")

    con = sqlite3.connect(DB_PATH)
    written = 0
    for name, etymology in cache.items():
        if not etymology or len(etymology) < 10:
            continue
        written += con.execute(
            "UPDATE names SET etymology = ? WHERE name = ? AND (etymology IS NULL OR etymology = '')",
            (etymology, name),
        ).rowcount
    con.commit()
    con.close()

    total_etym = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True).execute(
        "SELECT COUNT(*) FROM names WHERE etymology IS NOT NULL AND etymology != ''"
    ).fetchone()[0]

    print(f"✓ {written} prénoms mis à jour")
    print(f"✓ Total avec étymologie : {total_etym}")
    print(f"\n💶 Coût total : ${total_cost:.4f}  (≈ {total_cost * EUR_PER_USD:.2f}€)")


if __name__ == "__main__":
    main()
