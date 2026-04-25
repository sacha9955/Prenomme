# scripts/

Python scripts for generating the bundled `Resources/names.sqlite` catalogue.

## Prerequisites

Python 3.9+ required.

```bash
pip install -r scripts/requirements.txt
```

## Data sources

Place these in `data/raw/` (excluded from git):

| File | Source | Licence |
|------|--------|---------|
| `data/raw/prenoms-2024-nat.csv` | [INSEE Prénoms 2024](https://www.data.gouv.fr/fr/datasets/fichier-des-prenoms-edition-2024/) | Etalab Licence Ouverte v2 |
| `data/raw/ssa_us/yob*.txt` | [SSA Beyond the Top 1000](https://www.ssa.gov/oact/babynames/limits.html) | US Government public domain |

Wikidata enrichment is fetched at runtime and cached in `data/cache/wikidata_cache.json` (excluded from git, CC0).

## import_names.py

Generates `Resources/names.sqlite` from the raw data sources.

```bash
# Standard run (threshold ≥ 20 over 2015-2024)
python3 scripts/import_names.py

# Custom threshold
python3 scripts/import_names.py --threshold 10

# Skip Wikidata network requests (uses cache only)
python3 scripts/import_names.py --no-wikidata

# Dry run — parse and enrich without writing DB
python3 scripts/import_names.py --dry-run
```

**Steps:**

| Step | What |
|------|------|
| A | Parse INSEE `prenoms-2024-nat.csv` — names with ≥ 20 occurrences 2015-2024 |
| B | Parse SSA `yob*.txt` (2015-2024) — US name counts |
| C | Enrich with Wikidata SPARQL — French descriptions → origin + meaning |
| D | Apply `data/raw/manual_origins.csv` overrides (optional) |
| E | Compute syllables (pyphen) + approximate French IPA phonetics |
| F | Classify themes from descriptions |
| G | Write SQLite with 5 indexes + VACUUM |

Expected output: ~15,000–20,000 name+gender rows, ~5–8 MB.

## validate_db.py

Validates the generated DB meets quality thresholds before bundling.

```bash
python3 scripts/validate_db.py
```

Checks:
- > 15,000 rows
- > 80% with origin
- > 70% with meaning
- > 60% with FR popularity rank
- No duplicate `(name, gender)` pairs
- All 5 indexes present
- File size < 15 MB

Exits with code 1 if any check fails.

## manual_origins.csv (optional)

CSV override for origin/meaning data. Useful for names Wikidata doesn't cover well.

```
name,origin,meaning
Nolwenn,Breton,Sainte qui émigra en Bretagne au VIe siècle
Maëlys,Breton,Princesse au destin lumineux
```

## cleanup_simulator.sh

Removes all installed builds of the app from every booted simulator.
Run this before a fresh install to test the first-launch experience.

```bash
bash Scripts/cleanup_simulator.sh
```

Requires at least one simulator to be booted (`xcrun simctl boot <UDID>` or via Xcode).

## Full pipeline

```bash
python3 scripts/import_names.py
python3 scripts/validate_db.py
# If validation passes: open Xcode and build the app
```
