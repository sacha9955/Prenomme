#!/usr/bin/env python3
"""
enrich_etymology.py — Génère l'étymologie de tous les prénoms sans donnée.

Modes :
    1. SDK Anthropic (rapide)    : ANTHROPIC_API_KEY=sk-... python3 Scripts/enrich_etymology.py --yes
    2. CLI Claude Code (gratuit) : python3 Scripts/enrich_etymology.py --use-cli --yes
    3. Auto                      : --use-cli est activé automatiquement sans ANTHROPIC_API_KEY

Flags :
    --yes              Ne demande pas confirmation avant écriture DB
    --use-cli          Utilise `claude -p` (Claude Code headless) au lieu du SDK
    --dry-run          1 batch, pas d'écriture
    --sample N         Limiter à N prénoms
    --estimate-only    Affiche le coût, sans appel
    --batch-size N     Taille batch (défaut 20 SDK / 50 CLI)
    --priority-only    Seulement prénoms avec rang de popularité

Sortie : Resources/names.sqlite
Cache  : data/cache/etymology_cache.json
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

# ── Chemins ───────────────────────────────────────────────────────────────────

ROOT       = Path(__file__).parent.parent
DB_PATH    = ROOT / "Resources" / "names.sqlite"
DB_BACKUP  = ROOT / "Resources" / "names_before_etymology.sqlite"
CACHE_PATH = ROOT / "data" / "cache" / "etymology_cache.json"

# ── Tarification Haiku 4.5 (USD / token) ─────────────────────────────────────

PRICE_INPUT_PER_M  = 0.80
PRICE_OUTPUT_PER_M = 4.00
EUR_PER_USD        = 0.92

# ── Prompts ───────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = (
    "Onomasticien. Tu génères des étymologies UNE PHRASE en français (max 25 mots), "
    "factuelles, mentionnant origine linguistique + sens. Aucun préambule."
)


def _build_prompt(names_with_info: list[dict]) -> str:
    lines = []
    for item in names_with_info:
        info_parts = []
        if item.get("origin") and item["origin"] not in ("Autre", ""):
            info_parts.append(f"origine: {item['origin']}")
        if item.get("gender"):
            gender_fr = {"male": "masculin", "female": "féminin", "unisex": "épicène"}.get(item["gender"], "")
            if gender_fr:
                info_parts.append(f"genre: {gender_fr}")
        info = f" ({', '.join(info_parts)})" if info_parts else ""
        lines.append(f"- {item['name']}{info}")

    names_block = "\n".join(lines)
    return f"""\
Étymologies (1 phrase, max 25 mots, FR). Format strict: "NOM: étymologie", une ligne par prénom, sans numéro ni préambule.

{names_block}"""


# ── Estimation coût ───────────────────────────────────────────────────────────

def estimate_cost(total_names: int, batch_size: int) -> dict:
    n_batches = (total_names + batch_size - 1) // batch_size
    input_tokens_per  = 150 + batch_size * 12   # prompt compact + infos noms
    output_tokens_per = batch_size * 30          # ~30 tokens par étymologie (1 phrase)
    total_input  = int(n_batches * input_tokens_per)
    total_output = int(n_batches * output_tokens_per)
    cost_usd = (total_input * PRICE_INPUT_PER_M + total_output * PRICE_OUTPUT_PER_M) / 1_000_000
    return {
        "batches":       n_batches,
        "input_tokens":  total_input,
        "output_tokens": total_output,
        "cost_usd":      cost_usd,
        "cost_eur":      cost_usd * EUR_PER_USD,
    }


# ── Cache ─────────────────────────────────────────────────────────────────────

def load_cache() -> dict[str, str]:
    if CACHE_PATH.exists():
        with CACHE_PATH.open(encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_cache(cache: dict[str, str]) -> None:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CACHE_PATH.open("w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)


# ── Appel LLM ─────────────────────────────────────────────────────────────────

def _parse_response(raw: str, items: list[dict]) -> dict[str, str]:
    """Parse 'NOM: étymologie' lines into a dict."""
    result: dict[str, str] = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line or ": " not in line:
            continue
        name_part, etymology = line.split(": ", 1)
        clean_name = name_part.lstrip("-•* ").strip()
        if etymology.strip() and len(etymology.strip()) >= 10:
            result[clean_name] = etymology.strip()
    return result


def generate_batch_cli(
    items: list[dict],
    retry_delays: tuple[float, ...] = (10.0, 30.0, 60.0),
) -> dict[str, str] | None:
    """Appelle `claude -p` headless. Retourne {name: etymology} ou None si échec."""
    prompt = SYSTEM_PROMPT + "\n\n" + _build_prompt(items)
    last_error = None
    for attempt, delay in enumerate((-1,) + retry_delays):
        if attempt > 0:
            print(f"    ↺ retry {attempt}/{len(retry_delays)} dans {delay}s…", flush=True)
            time.sleep(delay)
        try:
            proc = subprocess.run(
                ["claude", "-p", "--model", "claude-haiku-4-5", prompt],
                capture_output=True, text=True, timeout=300,
            )
            # Parse stdout even if exit != 0 — claude-mem SessionEnd hook can return exit 1
            # while stdout still contains the model's full response.
            raw = (proc.stdout or "").strip()
            if not raw:
                last_error = f"empty stdout, exit {proc.returncode}: {proc.stderr[:200]}"
                continue
            result = _parse_response(raw, items)
            found = sum(1 for item in items if item["name"] in result)
            if found < len(items) // 2:
                last_error = f"partial ({found}/{len(items)})"
                continue
            return result
        except subprocess.TimeoutExpired:
            last_error = "timeout"
            continue
        except Exception as exc:
            last_error = str(exc)
            continue
    print(f"    ✗ batch CLI abandonné : {last_error}", flush=True)
    return None


def generate_batch(
    client,
    items: list[dict],
    retry_delays: tuple[float, ...] = (5.0, 15.0, 45.0),
) -> dict[str, str] | None:
    """Appelle Claude Haiku pour un batch. Retourne {name: etymology} ou None si échec."""
    prompt = _build_prompt(items)
    last_error = None

    for attempt, delay in enumerate((-1,) + retry_delays):
        if attempt > 0:
            print(f"    ↺ retry {attempt}/{len(retry_delays)} dans {delay}s…", flush=True)
            time.sleep(delay)
        try:
            response = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=len(items) * 80,
                system=SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = response.content[0].text.strip()
            result: dict[str, str] = {}
            for line in raw.splitlines():
                line = line.strip()
                if not line:
                    continue
                if ": " in line:
                    name_part, etymology = line.split(": ", 1)
                    # Normalise le nom (retire éventuels tirets/espaces parasites)
                    clean_name = name_part.lstrip("- ").strip()
                    if etymology.strip():
                        result[clean_name] = etymology.strip()

            # Vérifie qu'on a au moins 50% des noms
            found = sum(1 for item in items if item["name"] in result)
            if found < len(items) // 2:
                print(f"    ⚠ réponse partielle ({found}/{len(items)}) — retry", flush=True)
                last_error = "partial response"
                continue

            return result

        except Exception as exc:
            last_error = exc
            if "rate_limit" in str(exc).lower() or "429" in str(exc):
                continue
            print(f"    ✗ erreur non-retry : {exc}", flush=True)
            return None

    print(f"    ✗ batch abandonné : {last_error}", flush=True)
    return None


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run",       action="store_true", help="1 batch, sans écriture")
    parser.add_argument("--sample",        type=int, default=0,  help="Limiter à N prénoms")
    parser.add_argument("--estimate-only", action="store_true", help="Affiche le coût estimé")
    parser.add_argument("--batch-size",    type=int, default=0,  help="Prénoms par batch (défaut 20 SDK / 50 CLI)")
    parser.add_argument("--priority-only", action="store_true", help="Seulement prénoms avec rang popularité")
    parser.add_argument("--yes",           action="store_true", help="Skip confirmation avant écriture DB")
    parser.add_argument("--use-cli",       action="store_true", help="Utilise `claude -p` (gratuit) au lieu du SDK Anthropic")
    parser.add_argument("--parallel",      type=int, default=1,  help="Nombre de batches en parallèle (défaut 1, recommandé 6 pour CLI)")
    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key and not args.use_cli and not args.estimate_only:
        # Auto-fallback : si pas de clé API, on bascule sur claude CLI
        print("ℹ️  ANTHROPIC_API_KEY non définie → bascule auto sur --use-cli (Claude Code headless, gratuit)")
        args.use_cli = True

    if args.batch_size == 0:
        args.batch_size = 50 if args.use_cli else 20

    if not DB_PATH.exists():
        raise SystemExit(f"❌  DB introuvable : {DB_PATH}")

    # ── Charger les prénoms sans étymologie ──────────────────────────────────
    con = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    base_query = """
        SELECT name, gender, origin
        FROM names
        WHERE (etymology IS NULL OR etymology = '')
        {filter}
        ORDER BY
            COALESCE(popularity_rank_fr, 99999),
            COALESCE(popularity_rank_us, 99999),
            name
    """
    if args.priority_only:
        query = base_query.format(filter="AND (popularity_rank_fr IS NOT NULL OR popularity_rank_us IS NOT NULL)")
    else:
        query = base_query.format(filter="")

    rows = con.execute(query).fetchall()
    con.close()

    all_items = [{"name": r[0], "gender": r[1], "origin": r[2]} for r in rows]
    if args.sample:
        all_items = all_items[:args.sample]

    total = len(all_items)

    # ── Estimation coût ───────────────────────────────────────────────────────
    est = estimate_cost(total, args.batch_size)
    print(f"\n{'─'*60}")
    print(f"  Prénoms sans étymologie : {total:,}")
    print(f"  Batches                 : {est['batches']:,}  (taille {args.batch_size})")
    print(f"  Tokens input estimés    : {est['input_tokens']:,}")
    print(f"  Tokens output estimés   : {est['output_tokens']:,}")
    print(f"  Coût estimé             : ${est['cost_usd']:.2f}  (≈ {est['cost_eur']:.2f}€)")
    print(f"{'─'*60}\n")

    if args.estimate_only:
        return

    # ── Cache ─────────────────────────────────────────────────────────────────
    cache = load_cache()
    cached_hits = sum(1 for item in all_items if item["name"] in cache)
    to_fetch = [item for item in all_items if item["name"] not in cache]
    print(f"  Cache hits      : {cached_hits:,}")
    print(f"  À appeler API   : {len(to_fetch):,}\n")

    if args.dry_run:
        to_fetch = to_fetch[:args.batch_size]

    if args.use_cli:
        client = None
        print(f"  Mode             : CLI (claude -p, gratuit)\n")
    else:
        import anthropic
        client = anthropic.Anthropic(api_key=api_key)
        print(f"  Mode             : SDK Anthropic (Haiku 4.5)\n")

    # ── Boucle de génération ──────────────────────────────────────────────────
    batches = [to_fetch[i:i + args.batch_size] for i in range(0, len(to_fetch), args.batch_size)]
    total_cost_usd = 0.0

    def _run_batch(idx_batch):
        idx, batch = idx_batch
        if args.use_cli:
            res = generate_batch_cli(batch)
        else:
            res = generate_batch(client, batch)
        return idx, batch, res

    if args.parallel > 1 and not args.dry_run:
        from concurrent.futures import ThreadPoolExecutor, as_completed
        print(f"  Parallélisme     : {args.parallel} batches simultanés\n", flush=True)
        with ThreadPoolExecutor(max_workers=args.parallel) as executor:
            futures = [executor.submit(_run_batch, (i + 1, b)) for i, b in enumerate(batches)]
            for n, fut in enumerate(as_completed(futures), 1):
                idx, batch, result = fut.result()
                if result is None:
                    print(f"  Batch {idx:>4}/{len(batches)}  SKIP", flush=True)
                    continue
                cache.update(result)
                save_cache(cache)
                input_tok  = 400 + len(batch) * 15
                output_tok = len(batch) * 60
                batch_cost = (input_tok * PRICE_INPUT_PER_M + output_tok * PRICE_OUTPUT_PER_M) / 1_000_000
                total_cost_usd += batch_cost
                pct = 100 * n // len(batches)
                cost_lbl = "" if args.use_cli else f"  — {total_cost_usd * EUR_PER_USD:.3f}€"
                print(f"  Batch {idx:>4}/{len(batches)}  ({len(batch)} prénoms)  ✓  {len(result)} générées  [{pct:>3}%]{cost_lbl}", flush=True)
    else:
        for idx, batch in enumerate(batches, 1):
            cost_so_far_eur = total_cost_usd * EUR_PER_USD
            cost_label = "" if args.use_cli else f"  — {cost_so_far_eur:.3f}€"
            print(f"  Batch {idx:>4}/{len(batches)}  ({len(batch)} prénoms){cost_label}", end="  ", flush=True)

            if args.use_cli:
                result = generate_batch_cli(batch)
            else:
                result = generate_batch(client, batch)
            if result is None:
                print("SKIP")
                continue

            cache.update(result)
            save_cache(cache)

            input_tok  = 400 + len(batch) * 15
            output_tok = len(batch) * 60
            batch_cost = (input_tok * PRICE_INPUT_PER_M + output_tok * PRICE_OUTPUT_PER_M) / 1_000_000
            total_cost_usd += batch_cost

            print(f"✓  ({len(result)} étymologies générées)")

            if args.dry_run:
                # Affiche un exemple
                print("\n  Exemple d'étymologies générées :")
                for name, etym in list(result.items())[:3]:
                    print(f"    {name}: {etym[:80]}{'…' if len(etym) > 80 else ''}")
                print("\n[DRY-RUN] Aucune écriture DB.")
                break

            time.sleep(1.0)

    # ── Écriture en base ──────────────────────────────────────────────────────
    if not args.dry_run:
        total_cached = len(cache)
        print(f"\n  Cache total : {total_cached:,} étymologies")

        if total_cached == 0:
            print("  Rien à écrire.")
            return

        print(f"\n⚠️  Prêt à écrire {total_cached:,} étymologies dans {DB_PATH.name}")
        if args.yes:
            print("  --yes → confirmation skipée")
        else:
            confirm = input("  Confirmer ? [o/N] ").strip().lower()
            if confirm != "o":
                print("  Annulé.")
                return

        # Backup avant modification
        shutil.copy2(DB_PATH, DB_BACKUP)
        print(f"✓ Backup : {DB_BACKUP.name}")

        con = sqlite3.connect(DB_PATH)
        written = 0
        skipped = 0
        for name, etymology in cache.items():
            if not etymology or len(etymology) < 10:
                skipped += 1
                continue
            rows_updated = con.execute(
                "UPDATE names SET etymology = ? WHERE name = ? AND (etymology IS NULL OR etymology = '')",
                (etymology, name),
            ).rowcount
            written += rows_updated

        con.commit()
        con.close()

        print(f"✓ {written:,} prénoms mis à jour  ({skipped} ignorés — trop courts)")
        _print_report()

    total_cost_eur = total_cost_usd * EUR_PER_USD
    print(f"\n💶 Coût total API : ${total_cost_usd:.4f}  (≈ {total_cost_eur:.2f}€)")
    print(f"✓ Cache : {len(cache):,} entrées → {CACHE_PATH}")


def _print_report() -> None:
    con = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    total = con.execute("SELECT COUNT(*) FROM names").fetchone()[0]
    with_etym = con.execute(
        "SELECT COUNT(*) FROM names WHERE etymology IS NOT NULL AND etymology != ''"
    ).fetchone()[0]
    without = total - with_etym
    print(f"\n── Couverture étymologie ────────────────────────────────────────")
    print(f"  Avec étymologie    : {with_etym:>7,}  ({100*with_etym//total}%)")
    print(f"  Sans étymologie    : {without:>7,}  ({100*without//total}%)")
    print(f"  Total              : {total:>7,}")
    con.close()


if __name__ == "__main__":
    main()
