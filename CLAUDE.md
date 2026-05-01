# Prénomme — CLAUDE.md (root)

> App iOS native 100% offline pour choix de prénom de bébé. Catalogue 45k+ prénoms, phonétique locale, IAP non-consommable, widgets gratuits + Pro.

## Stack
- **iOS native** : Swift 5.10, SwiftUI 100%, Xcode 16.3, iOS 17.5+
- **Catalogue** : GRDB.swift 6.29.3+ → `Resources/names.sqlite` (read-only, bundle-embedded)
- **Données user** : SwiftData + CloudKit (Favorites, Notes, UserSettings, sync iCloud natif)
- **IAP** : StoreKit 2 — produit unique non-consommable `prenomme.pro.lifetime`
- **Phonétique** : NaturalLanguage framework (zéro réseau)
- **TTS** : AVSpeechSynthesizer (locale dynamique selon `origin_locale`)
- **Widgets** : WidgetKit (Prénom du jour gratuit + Pro personnalisable)
- **Export PDF** : PDFKit (feature Pro)

## Identifiants
- **Bundle ID** : `com.sacha9955.prenomme`
- **Team ID** : `Y9U6L9TB4B`
- **App Group** : `group.com.sacha9955.prenomme`
- **Repo** : `git@github.com:sacha9955/Prenomme.git`

## Architecture
Voir `ARCHITECTURE.md` (root, exhaustif).

Couches strictement séparées :
- **GRDB** = catalogue read-only (jamais modifié à l'exécution)
- **SwiftData + CloudKit** = données utilisateur (sync iCloud)

## Build
```bash
xcodegen   # régénère Prenomme.xcodeproj depuis project.yml
open Prenomme.xcodeproj
# build : Cmd+R
```

## Submit App Store
Déléguer à l'agent **`appstore`** (cf. `.claude/quickstart.md`).

## Précautions critiques
- Algorithme phonétique : utiliser `pure = {a,e,i,o,u}` pour le SCORING ; `vowels` complet (inclut 'y') pour la linguistique uniquement (cf. `.claude/project-memory.md`).
- IAP en DEBUG : bypass via `setDebugForcePro(true)` (UserDefaults app group). NE JAMAIS exposer en production.
- Étymologies : prompt 3 phrases (origine, sens, contexte). Ne PAS compresser le prompt système (qualité prime sur tokens).

## Tests
- `Tests/PrenommeTests/` (XCTest unitaires)
- `Tests/PrenommeUITests/` (UI tests)

## Scripts utilitaires
- `Scripts/reenrich_short_etymologies.py` — ré-enrichissement étymologies via `claude -p --model claude-haiku-4-5`
- `Scripts/import_names.py` — génère `names.sqlite` depuis `data/raw/*.csv`

## Reprise de session
Lire dans l'ordre : `.claude/CLAUDE.md` → `.claude/project-memory.md` → `.claude/checkpoints/latest.md` → `git status` → fichiers concernés uniquement.
