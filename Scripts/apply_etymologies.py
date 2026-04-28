#!/usr/bin/env python3
"""
apply_etymologies.py — Applique les étymologies des fichiers de cache JSON à la base SQLite.

Usage:
    python3 Scripts/apply_etymologies.py
    python3 Scripts/apply_etymologies.py --dry-run
"""
from __future__ import annotations

import argparse
import json
import shutil
import sqlite3
from pathlib import Path

ROOT      = Path(__file__).parent.parent
DB_PATH   = ROOT / "Resources" / "names.sqlite"
DB_BACKUP = ROOT / "Resources" / "names_before_etym.sqlite"
CACHE_DIR = ROOT / "data" / "cache"

BATCH_FILES = sorted(CACHE_DIR.glob("etymologies_batch*.json"))


def load_all_etymologies() -> dict[str, str]:
    merged: dict[str, str] = {}
    for path in BATCH_FILES:
        if not path.exists():
            print(f"  ⚠ Fichier manquant : {path.name}")
            continue
        with path.open(encoding="utf-8") as f:
            data = json.load(f)
        print(f"  ✓ {path.name} : {len(data)} étymologies")
        merged.update(data)
    return merged


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Affiche sans écrire en base")
    args = parser.parse_args()

    if not DB_PATH.exists():
        raise SystemExit(f"❌  DB introuvable : {DB_PATH}")

    print("\nChargement des fichiers de cache…")
    etymologies = load_all_etymologies()
    print(f"\n  Total étymologies disponibles : {len(etymologies)}\n")

    con_ro = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    already = {
        row[0] for row in con_ro.execute(
            "SELECT name FROM names WHERE etymology IS NOT NULL AND etymology != ''"
        )
    }
    names_in_db = {
        row[0] for row in con_ro.execute("SELECT name FROM names")
    }
    con_ro.close()

    to_write = {
        name: etym
        for name, etym in etymologies.items()
        if name in names_in_db and name not in already and len(etym) >= 10
    }
    skipped_not_in_db = [n for n in etymologies if n not in names_in_db]
    skipped_already   = [n for n in etymologies if n in already]

    print(f"  Déjà en base           : {len(already)}")
    print(f"  Nom absent de la DB    : {len(skipped_not_in_db)}")
    print(f"  À écrire               : {len(to_write)}")

    if skipped_not_in_db:
        print(f"\n  Noms absents de la DB : {', '.join(sorted(skipped_not_in_db)[:20])}"
              + (" …" if len(skipped_not_in_db) > 20 else ""))

    if args.dry_run:
        print("\n[DRY-RUN] Exemples :")
        for name, etym in list(to_write.items())[:5]:
            print(f"  {name}: {etym[:90]}{'…' if len(etym) > 90 else ''}")
        print("\n[DRY-RUN] Aucune écriture effectuée.")
        return

    if not to_write:
        print("\n  Rien à écrire.")
        return

    shutil.copy2(DB_PATH, DB_BACKUP)
    print(f"\n✓ Backup : {DB_BACKUP.name}")

    con = sqlite3.connect(DB_PATH)
    written = 0
    for name, etym in to_write.items():
        written += con.execute(
            "UPDATE names SET etymology = ? WHERE name = ? AND (etymology IS NULL OR etymology = '')",
            (etym, name),
        ).rowcount
    con.commit()

    total_etym = con.execute(
        "SELECT COUNT(*) FROM names WHERE etymology IS NOT NULL AND etymology != ''"
    ).fetchone()[0]
    total_names = con.execute("SELECT COUNT(*) FROM names").fetchone()[0]
    con.close()

    print(f"✓ {written} prénoms mis à jour")
    print(f"✓ Total avec étymologie : {total_etym} / {total_names}")


if __name__ == "__main__":
    main()
