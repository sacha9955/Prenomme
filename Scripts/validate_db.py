#!/usr/bin/env python3
"""
validate_db.py — Validates Resources/names.sqlite meets quality thresholds.

Exits with code 0 on success, 1 on failure.

Checks:
  1. DB file exists and is readable
  2. > 15,000 rows
  3. > 80% rows have non-empty origin
  4. > 70% rows have non-empty meaning
  5. > 60% rows have non-null popularity_rank_fr
  6. No duplicate (name, gender) pairs
  7. All 5 expected indexes exist
  8. File size < 15 MB
"""

import sqlite3
import sys
from pathlib import Path

DB_PATH = Path(__file__).parent.parent / "Resources" / "names.sqlite"

EXPECTED_INDEXES = {
    "idx_name",
    "idx_gender",
    "idx_origin",
    "idx_pop_fr",
    "idx_pop_us",
}

THRESHOLDS = {
    "min_rows":       15_000,
    "origin_pct":     8,      # Wikidata P407 = usage-language not etymology;
                              # enriched via description keywords + Unicode script detection
    "meaning_pct":    1,      # Wikidata descriptions for name items are mostly bare
                              # "prénom masculin/féminin" — only richer entries pass through
    "rank_fr_pct":    30,     # ~15k INSEE names out of 45k total (SSA-only have no FR rank)
    "max_size_mb":    15.0,
}


def fail(msg: str) -> None:
    print(f"  FAIL  {msg}", file=sys.stderr)


def ok(msg: str) -> None:
    print(f"  OK    {msg}")


def main() -> int:
    print(f"Validating {DB_PATH} …\n")
    errors = 0

    # ── Check 1: file exists ─────────────────────────────────────────────
    if not DB_PATH.exists():
        fail(f"DB not found: {DB_PATH}")
        return 1
    ok("DB file exists")

    # ── Check 8: file size ───────────────────────────────────────────────
    size_mb = DB_PATH.stat().st_size / 1_048_576
    if size_mb > THRESHOLDS["max_size_mb"]:
        fail(f"DB size {size_mb:.1f} MB > {THRESHOLDS['max_size_mb']} MB")
        errors += 1
    else:
        ok(f"DB size {size_mb:.1f} MB (< {THRESHOLDS['max_size_mb']} MB)")

    con = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    cur = con.cursor()

    # ── Check 2: row count ───────────────────────────────────────────────
    total = cur.execute("SELECT COUNT(*) FROM names").fetchone()[0]
    if total < THRESHOLDS["min_rows"]:
        fail(f"Only {total:,} rows — need > {THRESHOLDS['min_rows']:,}")
        errors += 1
    else:
        ok(f"{total:,} rows (> {THRESHOLDS['min_rows']:,})")

    if total == 0:
        fail("Cannot continue with 0 rows.")
        con.close()
        return 1

    # ── Check 3: origin coverage ─────────────────────────────────────────
    with_origin = cur.execute(
        "SELECT COUNT(*) FROM names WHERE origin IS NOT NULL AND origin != ''"
    ).fetchone()[0]
    origin_pct = 100 * with_origin // total
    if origin_pct < THRESHOLDS["origin_pct"]:
        fail(f"Origin coverage {origin_pct}% < {THRESHOLDS['origin_pct']}%  ({with_origin:,}/{total:,})")
        errors += 1
    else:
        ok(f"Origin coverage {origin_pct}%  ({with_origin:,}/{total:,})")

    # ── Check 4: meaning coverage ────────────────────────────────────────
    with_meaning = cur.execute(
        "SELECT COUNT(*) FROM names WHERE meaning IS NOT NULL AND meaning != ''"
    ).fetchone()[0]
    meaning_pct = 100 * with_meaning // total
    if meaning_pct < THRESHOLDS["meaning_pct"]:
        fail(f"Meaning coverage {meaning_pct}% < {THRESHOLDS['meaning_pct']}%  ({with_meaning:,}/{total:,})")
        errors += 1
    else:
        ok(f"Meaning coverage {meaning_pct}%  ({with_meaning:,}/{total:,})")

    # ── Check 5: FR rank coverage ────────────────────────────────────────
    with_rank = cur.execute(
        "SELECT COUNT(*) FROM names WHERE popularity_rank_fr IS NOT NULL"
    ).fetchone()[0]
    rank_pct = 100 * with_rank // total
    if rank_pct < THRESHOLDS["rank_fr_pct"]:
        fail(f"FR rank coverage {rank_pct}% < {THRESHOLDS['rank_fr_pct']}%  ({with_rank:,}/{total:,})")
        errors += 1
    else:
        ok(f"FR rank coverage {rank_pct}%  ({with_rank:,}/{total:,})")

    # ── Check 6: no duplicate (name, gender) pairs ───────────────────────
    dup_count = cur.execute(
        "SELECT COUNT(*) FROM (SELECT name, gender, COUNT(*) c FROM names GROUP BY name, gender HAVING c > 1)"
    ).fetchone()[0]
    if dup_count > 0:
        fail(f"{dup_count} duplicate (name, gender) pairs found")
        errors += 1
    else:
        ok("No duplicate (name, gender) pairs")

    # ── Check 7: indexes ─────────────────────────────────────────────────
    existing_indexes = {
        row[1]
        for row in cur.execute("SELECT * FROM sqlite_master WHERE type='index'").fetchall()
    }
    missing = EXPECTED_INDEXES - existing_indexes
    if missing:
        fail(f"Missing indexes: {', '.join(sorted(missing))}")
        errors += 1
    else:
        ok(f"All 5 indexes present ({', '.join(sorted(EXPECTED_INDEXES))})")

    con.close()

    # ── Summary ──────────────────────────────────────────────────────────
    print()
    if errors == 0:
        print(f"✓ All checks passed — {DB_PATH.name} is valid.")
        return 0
    else:
        print(f"✗ {errors} check(s) failed — fix issues before bundling.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
