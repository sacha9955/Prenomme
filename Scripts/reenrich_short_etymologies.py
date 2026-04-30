#!/usr/bin/env python3
"""
reenrich_short_etymologies.py — Re-génère les étymologies trop courtes (< threshold) avec un prompt QUALITÉ.

Usage:
    python3 Scripts/reenrich_short_etymologies.py --threshold 100 --yes
    python3 Scripts/reenrich_short_etymologies.py --threshold 50 --priority-only --yes
    python3 Scripts/reenrich_short_etymologies.py --sample 20 --dry-run

Options:
    --threshold N       Cible les étymologies < N chars (défaut: 100)
    --priority-only     Seulement les prénoms avec rang FR ou US
    --sample N          Limiter à N prénoms
    --batch-size N      Prénoms par batch (défaut: 30 — plus petit pour qualité)
    --parallel N        Workers parallèles (défaut: 6)
    --yes               Skip confirmation DB
    --dry-run           1 batch sans écrire
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

ROOT      = Path(__file__).parent.parent
DB_PATH   = ROOT / "Resources" / "names.sqlite"
DB_BACKUP = ROOT / "Resources" / "names_before_reenrich.sqlite"
CACHE_PATH = ROOT / "data" / "cache" / "reenrich_etymology_cache.json"

# Quality system prompt — 3 phrases, riche en info linguistique
SYSTEM_PROMPT = (
    "Tu es un onomasticien (expert en étymologie des prénoms). "
    "Tu génères des étymologies de qualité en français (2 à 3 phrases, 50 à 90 mots), "
    "qui DOIVENT contenir : (1) l'origine linguistique (langue + racine étymologique précise avec le mot d'origine), "
    "(2) le sens littéral du prénom, (3) un élément culturel/historique de diffusion (saint, roi, héros, époque). "
    "INTERDIT : 'Prénom masculin', 'Prénom féminin', 'Prénom épicène', mentions d'alphabet seul. "
    "L'étymologie doit être substantielle, pas un résumé."
)


def build_prompt(items):
    lines = []
    for item in items:
        info = []
        if item.get("origin") and item["origin"] not in ("Autre", ""):
            info.append(f"origine connue: {item['origin']}")
        if item.get("gender"):
            g = {"male": "masculin", "female": "féminin", "unisex": "épicène"}.get(item["gender"], "")
            if g: info.append(f"genre: {g}")
        info_str = f" ({', '.join(info)})" if info else ""
        lines.append(f"- {item['name']}{info_str}")
    block = "\n".join(lines)
    return (f"Pour chaque prénom, génère une étymologie SUBSTANTIELLE (2-3 phrases, 50-90 mots) "
            f"avec origine linguistique précise, sens littéral, et contexte culturel.\n\n"
            f"Format STRICT : une ligne par prénom, format \"NOM: étymologie\".\n"
            f"Pas de préambule, pas de numérotation.\n\n"
            f"Prénoms :\n{block}")


def parse_response(raw, items):
    result = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line or ": " not in line: continue
        name_part, etym = line.split(": ", 1)
        clean = name_part.lstrip("-•* ").strip()
        # Accept anything substantial (50+ chars) — DB threshold is 100 so any improvement counts
        if etym.strip() and len(etym.strip()) >= 50:
            result[clean] = etym.strip()
    return result


def generate_batch(items, retry_delays=(10, 30, 60)):
    prompt = SYSTEM_PROMPT + "\n\n" + build_prompt(items)
    last_err = None
    for attempt, delay in enumerate((-1,) + retry_delays):
        if attempt > 0:
            print(f"    ↺ retry {attempt}/{len(retry_delays)} dans {delay}s…", flush=True)
            time.sleep(delay)
        try:
            proc = subprocess.run(
                ["claude", "-p", "--model", "claude-haiku-4-5", prompt],
                capture_output=True, text=True, timeout=300,
            )
            raw = (proc.stdout or "").strip()
            if not raw:
                last_err = f"empty stdout, exit {proc.returncode}"
                continue
            result = parse_response(raw, items)
            found = sum(1 for it in items if it["name"] in result)
            if found < len(items) // 2:
                last_err = f"partial ({found}/{len(items)})"
                continue
            return result
        except subprocess.TimeoutExpired:
            last_err = "timeout"; continue
        except Exception as e:
            last_err = str(e); continue
    print(f"    ✗ batch abandonné : {last_err}", flush=True)
    return None


def load_cache():
    if CACHE_PATH.exists():
        with CACHE_PATH.open(encoding="utf-8") as f:
            return json.load(f)
    return {}

def save_cache(cache):
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CACHE_PATH.open("w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--threshold", type=int, default=100)
    p.add_argument("--priority-only", action="store_true")
    p.add_argument("--sample", type=int, default=0)
    p.add_argument("--batch-size", type=int, default=30)
    p.add_argument("--parallel", type=int, default=6)
    p.add_argument("--yes", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    con = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    base = f"""
        SELECT name, gender, origin
        FROM names
        WHERE etymology IS NOT NULL AND length(etymology) < {args.threshold}
        {{prio}}
        ORDER BY COALESCE(popularity_rank_fr, 99999),
                 COALESCE(popularity_rank_us, 99999),
                 name
    """
    prio = "AND (popularity_rank_fr IS NOT NULL OR popularity_rank_us IS NOT NULL)" if args.priority_only else ""
    rows = con.execute(base.format(prio=prio)).fetchall()
    con.close()

    items = [{"name": r[0], "gender": r[1], "origin": r[2]} for r in rows]
    if args.sample:
        items = items[:args.sample]

    print(f"\n{'─'*60}")
    print(f"  Étymologies < {args.threshold} chars : {len(items):,}")
    if args.priority_only:
        print(f"  Filtre : prénoms avec rang popularité")
    print(f"  Batch size : {args.batch_size}  /  Parallèles : {args.parallel}")
    print(f"{'─'*60}\n")

    cache = load_cache()
    to_fetch = [it for it in items if it["name"] not in cache]
    print(f"  Cache hits  : {len(items) - len(to_fetch):,}")
    print(f"  À fetcher   : {len(to_fetch):,}\n")

    if args.dry_run:
        to_fetch = to_fetch[:args.batch_size]

    batches = [to_fetch[i:i+args.batch_size] for i in range(0, len(to_fetch), args.batch_size)]
    print(f"  → {len(batches)} batches\n", flush=True)

    def run(idx_batch):
        idx, b = idx_batch
        return idx, b, generate_batch(b)

    if args.parallel > 1 and not args.dry_run:
        with ThreadPoolExecutor(max_workers=args.parallel) as ex:
            futures = [ex.submit(run, (i+1, b)) for i, b in enumerate(batches)]
            done = 0
            for fut in as_completed(futures):
                idx, batch, res = fut.result()
                done += 1
                if res is None:
                    print(f"  Batch {idx:>4}/{len(batches)}  SKIP", flush=True)
                    continue
                cache.update(res)
                save_cache(cache)
                pct = 100 * done // len(batches)
                print(f"  Batch {idx:>4}/{len(batches)}  ({len(batch)} noms)  ✓ {len(res)} générés  [{pct}%]", flush=True)
    else:
        for idx, batch in enumerate(batches, 1):
            print(f"  Batch {idx:>4}/{len(batches)}  ({len(batch)} noms)…", end="  ", flush=True)
            res = generate_batch(batch)
            if res is None:
                print("SKIP")
                continue
            cache.update(res)
            save_cache(cache)
            print(f"✓ {len(res)} générés")
            if args.dry_run:
                for n, e in list(res.items())[:3]:
                    print(f"    {n}: {e[:100]}…")
                print("\n[DRY-RUN] No DB write.")
                return

    if not args.dry_run and cache:
        if not args.yes:
            print(f"\n⚠️  Écraser {len(cache):,} étymologies dans {DB_PATH.name} ?")
            if input("  o/N : ").strip().lower() != "o":
                return
        shutil.copy2(DB_PATH, DB_BACKUP)
        print(f"✓ Backup : {DB_BACKUP.name}")
        c = sqlite3.connect(DB_PATH)
        written = 0
        for name, etym in cache.items():
            # Only write if new etymology is longer than existing
            if len(etym) < 50: continue
            cur = c.execute("UPDATE names SET etymology = ? WHERE name = ? AND length(etymology) < length(?)",
                            (etym, name, etym))
            written += cur.rowcount
        c.commit()
        # Final coverage
        total = c.execute("SELECT COUNT(*) FROM names").fetchone()[0]
        bad = c.execute(f"SELECT COUNT(*) FROM names WHERE length(etymology) < {args.threshold}").fetchone()[0]
        c.close()
        print(f"\n✓ {written:,} étymologies mises à jour")
        print(f"  Restant < {args.threshold} chars : {bad:,} / {total:,}")


if __name__ == "__main__":
    main()
