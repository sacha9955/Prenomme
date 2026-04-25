#!/usr/bin/env python3
"""
enrich_with_llm.py — Classifie les 38 960 prénoms "Autre" via Claude Haiku.

Usage:
    ANTHROPIC_API_KEY=sk-... python3 scripts/enrich_with_llm.py
    python3 scripts/enrich_with_llm.py --dry-run          # 1 batch, pas d'écriture
    python3 scripts/enrich_with_llm.py --sample 100       # N prénoms seulement
    python3 scripts/enrich_with_llm.py --estimate-only    # coût estimé, sans appel API
    python3 scripts/enrich_with_llm.py --batch-size 30    # override taille batch (défaut 50)

Sortie : Resources/names_enriched.sqlite (copie enrichie, names.sqlite non modifié)
Cache  : data/cache/llm_origins_cache.json
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

# ── Chemins ───────────────────────────────────────────────────────────────────

ROOT       = Path(__file__).parent.parent
DB_SRC     = ROOT / "Resources" / "names.sqlite"
DB_DST     = ROOT / "Resources" / "names_enriched.sqlite"
CACHE_PATH = ROOT / "data" / "cache" / "llm_origins_cache.json"

# ── Mapping réponse LLM → valeur DB ──────────────────────────────────────────
# LLM utilise ~29 catégories, on mappe vers le palette OriginService.

LLM_TO_DB: dict[str, str] = {
    "Hébreu":      "Hébreu",
    "Grec":        "Grec",
    "Latin":       "Latin",
    "Arabe":       "Arabe",
    "Japonais":    "Japonais",
    "Nordique":    "Nordique",
    "Germanique":  "Germanique",
    "Slave":       "Slave",
    "Anglais":     "Anglais",
    "Français":    "Latin",      # noms français souvent d'orig. latine/germanique
    "Italien":     "Latin",      # italien → racines latines
    "Espagnol":    "Espagnol",
    "Portugais":   "Espagnol",   # famille ibérique
    "Indien":      "Sanskrit",   # Sanskrit couvre l'Inde
    "Africain":    "Autre",      # trop générique
    "Coréen":      "Coréen",
    "Chinois":     "Chinois",
    "Turc":        "Autre",
    "Persan":      "Perse",
    "Vietnamien":  "Autre",
    "Polynésien":  "Autre",
    "Amérindien":  "Autre",
    "Berbère":     "Autre",
    "Irlandais":   "Irlandais",
    "Écossais":    "Irlandais",  # famille celtique
    "Gallois":     "Gallois",
    "Breton":      "Breton",
    "Normand":     "Normand",
    "Inconnue":    "Autre",
}

VALID_LLM_CATEGORIES = set(LLM_TO_DB.keys())

# ── Tarification Haiku 3.5 (USD / token) ─────────────────────────────────────

PRICE_INPUT_PER_M  = 0.80   # $0.80 / 1M input tokens
PRICE_OUTPUT_PER_M = 4.00   # $4.00 / 1M output tokens
EUR_PER_USD        = 0.92

# ── Prompt ────────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = (
    "Tu es un expert en onomastique (étude des prénoms). "
    "Réponds UNIQUEMENT avec la liste demandée, sans explication."
)

def _build_user_prompt(names: list[str]) -> str:
    names_block = "\n".join(names)
    categories  = ", ".join(sorted(VALID_LLM_CATEGORIES))
    return f"""\
Pour chacun de ces prénoms, donne UNIQUEMENT l'origine culturelle/linguistique \
la plus probable parmi cette liste exacte (un seul mot par ligne) :
{categories}

Si tu n'es pas sûr à plus de 70%, réponds "Inconnue".

Format de réponse : juste la liste, un mot par ligne, dans le même ordre que les prénoms.

Prénoms :
{names_block}"""


# ── Estimation coût ───────────────────────────────────────────────────────────

def estimate_cost(total_names: int, batch_size: int) -> dict:
    n_batches        = (total_names + batch_size - 1) // batch_size
    # approximation : ~300 tokens input, ~75 tokens output par batch
    input_tokens_per = 300 + batch_size * 2   # prompt fixe + noms
    output_tokens_per = batch_size * 1.5      # 1-2 tokens par réponse
    total_input   = int(n_batches * input_tokens_per)
    total_output  = int(n_batches * output_tokens_per)
    cost_usd  = (total_input * PRICE_INPUT_PER_M + total_output * PRICE_OUTPUT_PER_M) / 1_000_000
    cost_eur  = cost_usd * EUR_PER_USD
    return {
        "batches":       n_batches,
        "input_tokens":  total_input,
        "output_tokens": total_output,
        "cost_usd":      cost_usd,
        "cost_eur":      cost_eur,
    }


# ── Cache ─────────────────────────────────────────────────────────────────────

def load_cache() -> dict[str, str]:
    if CACHE_PATH.exists():
        with CACHE_PATH.open() as f:
            return json.load(f)
    return {}

def save_cache(cache: dict[str, str]) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CACHE_PATH.open("w") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)


# ── Appel LLM ─────────────────────────────────────────────────────────────────

def classify_batch(
    client,
    names: list[str],
    retry_delays: tuple[float, ...] = (5.0, 15.0, 45.0),
) -> dict[str, str] | None:
    """
    Appelle Claude Haiku pour un batch. Retourne {name: db_origin} ou None si échec.
    """
    prompt = _build_user_prompt(names)
    last_error = None

    for attempt, delay in enumerate((-1,) + retry_delays):
        if attempt > 0:
            print(f"    ↺ retry {attempt}/{len(retry_delays)} dans {delay}s…", flush=True)
            time.sleep(delay)
        try:
            response = client.messages.create(
                model="claude-3-5-haiku-20241022",
                max_tokens=256,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = response.content[0].text.strip()
            lines = [l.strip() for l in raw.splitlines() if l.strip()]

            if len(lines) != len(names):
                print(f"    ⚠ batch mal formaté ({len(lines)} lignes pour {len(names)} noms) — skip", flush=True)
                return None

            result: dict[str, str] = {}
            for name, line in zip(names, lines):
                # normalise casse (LLM peut répondre "hébreu" au lieu de "Hébreu")
                matched = next(
                    (k for k in VALID_LLM_CATEGORIES if k.lower() == line.lower()),
                    None,
                )
                db_origin = LLM_TO_DB.get(matched or "", "Autre")
                result[name] = db_origin
            return result

        except Exception as exc:
            last_error = exc
            if "rate_limit" in str(exc).lower() or "429" in str(exc):
                continue
            print(f"    ✗ erreur non-retry : {exc}", flush=True)
            return None

    print(f"    ✗ batch abandonné après {len(retry_delays)} retries : {last_error}", flush=True)
    return None


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run",       action="store_true", help="1 batch, sans écriture")
    parser.add_argument("--sample",        type=int, default=0,  help="Limiter à N prénoms")
    parser.add_argument("--estimate-only", action="store_true", help="Affiche le coût estimé")
    parser.add_argument("--batch-size",    type=int, default=50, help="Prénoms par batch (défaut 50)")
    args = parser.parse_args()

    # ── Vérification clé API ──────────────────────────────────────────────────
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key and not args.estimate_only:
        print("❌  ANTHROPIC_API_KEY non définie.")
        print("    Lance avec : ANTHROPIC_API_KEY=sk-... python3 scripts/enrich_with_llm.py")
        sys.exit(1)

    if not DB_SRC.exists():
        raise SystemExit(f"❌  DB source introuvable : {DB_SRC}")

    # ── Charger les prénoms "Autre" ───────────────────────────────────────────
    con_src = sqlite3.connect(f"file:{DB_SRC}?mode=ro", uri=True)
    rows = con_src.execute(
        "SELECT DISTINCT name FROM names WHERE origin = 'Autre' ORDER BY "
        "COALESCE(popularity_rank_fr, 99999), COALESCE(popularity_rank_us, 99999), name"
    ).fetchall()
    con_src.close()

    all_names = [r[0] for r in rows]
    if args.sample:
        all_names = all_names[: args.sample]

    total = len(all_names)
    n_batches = (total + args.batch_size - 1) // args.batch_size

    # ── Estimation coût ───────────────────────────────────────────────────────
    est = estimate_cost(total, args.batch_size)
    print(f"\n{'─'*55}")
    print(f"  Prénoms à classer  : {total:,}")
    print(f"  Batches            : {est['batches']:,}  (taille {args.batch_size})")
    print(f"  Tokens input est.  : {est['input_tokens']:,}")
    print(f"  Tokens output est. : {est['output_tokens']:,}")
    print(f"  Coût estimé        : ${est['cost_usd']:.3f}  (≈ {est['cost_eur']:.2f}€)")
    print(f"{'─'*55}\n")

    if args.estimate_only:
        return

    # ── Préparer la DB destination ────────────────────────────────────────────
    if not args.dry_run:
        shutil.copy2(DB_SRC, DB_DST)
        print(f"✓ Copie de travail : {DB_DST.name}")
        con_dst = sqlite3.connect(DB_DST)
        _ensure_origin_source_column(con_dst)
    else:
        con_dst = None

    # ── Charger cache ─────────────────────────────────────────────────────────
    cache = load_cache()
    cached_hits = sum(1 for n in all_names if n in cache)
    to_fetch = [n for n in all_names if n not in cache]
    print(f"  Cache hits         : {cached_hits:,}")
    print(f"  À appeler API      : {len(to_fetch):,}\n")

    if args.dry_run:
        to_fetch = to_fetch[: args.batch_size]   # 1 batch max en dry-run

    import anthropic
    client = anthropic.Anthropic(api_key=api_key) if api_key else None

    # ── Boucle de classification ──────────────────────────────────────────────
    batches = [to_fetch[i: i + args.batch_size] for i in range(0, len(to_fetch), args.batch_size)]
    total_cost_usd = 0.0
    processed = 0

    for idx, batch in enumerate(batches, 1):
        cost_so_far_eur = total_cost_usd * EUR_PER_USD
        print(f"  Batch {idx:>4}/{len(batches)}  ({len(batch)} noms)  — coût estimé {cost_so_far_eur:.3f}€", end="  ", flush=True)

        result = classify_batch(client, batch)
        if result is None:
            print("SKIP")
            continue

        # Stocker dans cache
        cache.update(result)
        save_cache(cache)

        # Estimer coût de ce batch
        input_tok  = 300 + len(batch) * 2
        output_tok = len(batch) * 1.5
        batch_cost = (input_tok * PRICE_INPUT_PER_M + output_tok * PRICE_OUTPUT_PER_M) / 1_000_000
        total_cost_usd += batch_cost
        processed += len(batch)

        # Distribution rapide de ce batch
        by_origin: dict[str, int] = {}
        for o in result.values():
            by_origin[o] = by_origin.get(o, 0) + 1
        top3 = sorted(by_origin.items(), key=lambda x: -x[1])[:3]
        summary = ", ".join(f"{k}={v}" for k, v in top3)
        print(f"✓  [{summary}]")

        if args.dry_run:
            print("\n[DRY-RUN] Un batch traité. Aucune écriture DB.")
            break

        time.sleep(1.0)   # politesse rate-limit

    # ── Écrire en DB ──────────────────────────────────────────────────────────
    if not args.dry_run and con_dst:
        print(f"\n✎ Écriture en base…")
        written = 0
        for name, origin in cache.items():
            if origin == "Autre":
                continue   # pas la peine d'écraser "Autre" par "Autre"
            con_dst.execute(
                "UPDATE names SET origin = ?, origin_source = 'llm' WHERE name = ? AND origin = 'Autre'",
                (origin, name),
            )
            written += 1
        con_dst.commit()
        con_dst.close()
        print(f"✓ {written:,} prénoms mis à jour → {DB_DST.name}")

        # ── Rapport final ─────────────────────────────────────────────────────
        _print_report(DB_DST)

    total_cost_eur = total_cost_usd * EUR_PER_USD
    print(f"\n💶 Coût total API : ${total_cost_usd:.4f}  (≈ {total_cost_eur:.2f}€)")
    print(f"✓ Cache : {len(cache):,} entrées → {CACHE_PATH}")


def _ensure_origin_source_column(con: sqlite3.Connection) -> None:
    cols = {row[1] for row in con.execute("PRAGMA table_info(names)")}
    if "origin_source" not in cols:
        con.execute("ALTER TABLE names ADD COLUMN origin_source TEXT")
        con.commit()


def _print_report(db_path: Path) -> None:
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    total = con.execute("SELECT COUNT(*) FROM names").fetchone()[0]
    print(f"\n── Distribution post-enrichissement ({db_path.name}) ──────────────")
    rows = con.execute(
        "SELECT origin, COUNT(*) AS n FROM names GROUP BY origin ORDER BY n DESC LIMIT 15"
    ).fetchall()
    for origin, n in rows:
        pct = 100 * n // total
        bar = "█" * min(30, n * 30 // total)
        print(f"  {origin:<18} {n:>7,}  {pct:>3}%  {bar}")

    print(f"\n── Par source ────────────────────────────────────────────────────")
    rows = con.execute(
        "SELECT COALESCE(origin_source,'original') AS src, COUNT(*) AS n "
        "FROM names GROUP BY src ORDER BY n DESC"
    ).fetchall()
    for src, n in rows:
        pct = 100 * n // total
        print(f"  {src:<12} {n:>7,}  {pct}%")
    con.close()


if __name__ == "__main__":
    main()
