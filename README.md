# Prénomme

> "Trouvez le prénom qui lui ressemble déjà."

Application iOS native pour aider les futurs parents à trouver le prénom idéal de leur enfant. **100 % offline, zéro backend, zéro publicité, zéro tracker.** Catalogue de plus de 45 000 prénoms français et internationaux.

[![iOS 17.5+](https://img.shields.io/badge/iOS-17.5%2B-blue)](#)
[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange)](#)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-lightgrey)](#)

---

## Fonctionnalités

### Gratuit
- **Explorer** — Parcours et filtres (genre, origine, initiale, syllabes)
- **Swiper** — Découverte ludique (20 swipes/jour)
- **Favoris** — Jusqu'à 10 prénoms sauvegardés
- **Prénom du jour** — Widget natif iOS (gratuit)
- **Mode sombre** — Adaptatif Light/Dark complet

### Pro (3 formules)
- **Mensuel** — 2,99 € / mois
- **Annuel** — 19,99 € / an (économise 44 %)
- **À vie** — 29,99 € (paiement unique)

Toutes les formules débloquent :
- Suggestions intelligentes basées sur les favoris
- Analyse phonétique (compatibilité prénom/nom de famille)
- Comparateur de favoris côte à côte
- Étymologie complète (origine + sens + contexte)
- Prononciation audio (locale dynamique)
- Export PDF
- Widget Pro personnalisable
- Swipes et favoris illimités
- Filtres avancés

---

## Stack technique

| Couche | Outil |
|---|---|
| Langage | Swift 5.10+ |
| UI | SwiftUI 100 % |
| Min iOS | 17.5 (iPhone uniquement, iPad en v2) |
| Catalogue prénoms | SQLite via [GRDB.swift](https://github.com/groue/GRDB.swift) 6.29.3+ (read-only, bundle-embedded) |
| Persistance utilisateur | SwiftData + CloudKit (favoris, notes, settings) |
| IAP | StoreKit 2 — 1 lifetime + 2 abonnements |
| Phonétique | NaturalLanguage framework |
| Prononciation | AVSpeechSynthesizer (locale dynamique) |
| Widgets | WidgetKit |
| Export | PDFKit |
| Build | Xcode 16.3 + xcodegen |

**Aucun SDK tiers de tracking ou analytics.**

---

## Architecture rapide

```
Prenomme/
├── App/                    # Entry point, Info.plist, Assets, NavigationRouter
│   └── Assets.xcassets/    # Brand* + Gender* colorsets (light + dark variants)
├── Models/
│   ├── Domain/             # FirstName, Gender, etc. (modèles immutables read-only)
│   └── SwiftData/          # Favorite, UserSettings (CloudKit-synced)
├── Services/
│   ├── NameDatabase.swift  # GRDB read-only sur Resources/names.sqlite
│   ├── PurchaseManager.swift # StoreKit 2 + bypass DEBUG
│   ├── FavoriteService.swift, OriginService.swift, etc.
│   └── PhoneticAnalyzer.swift # Algorithme local (NaturalLanguage)
├── Views/
│   ├── DesignSystem/AppColors.swift  # Couleurs adaptatives Light/Dark
│   ├── Common/             # Modifiers réutilisables (ProGate, ICloudUnavailable)
│   ├── Home/, Browse/, Compatibility/, Swipe/, Favorites/, Settings/, Onboarding/, Paywall/
├── Widget/                 # Extension WidgetKit (Prénom du jour + Pro)
├── Resources/
│   ├── names.sqlite        # 45 274 prénoms (~15 MB, bundled)
│   └── Prenomme.storekit   # Config StoreKit locale Xcode
├── Tests/                  # XCTest unitaires + UI tests
├── Scripts/                # Outils Python (re-enrichissement étymologies, génération app icon)
└── AppStoreConnect/        # Metadata, guides submission, product IDs
```

Détails architecturaux complets dans [`ARCHITECTURE.md`](ARCHITECTURE.md).

### Couches strictement séparées

- **GRDB** = catalogue read-only (jamais modifié à l'exécution)
- **SwiftData + CloudKit** = données utilisateur (sync iCloud entre les appareils du même Apple ID)

### Mode sombre

Tout passe par `Color.brand`, `Color.genderFemale`, `Color.appSurface`, etc. (extension dans `Views/DesignSystem/AppColors.swift`). Aucun `Color(red:_,green:_,blue:_)` hardcodé en dehors du DesignSystem. Variantes Light/Dark définies dans `App/Assets.xcassets`.

---

## Build & Run

### Prérequis
- macOS 14+
- Xcode 16.3+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Setup
```bash
cd Prenomme
xcodegen                    # régénère Prenomme.xcodeproj depuis project.yml
open Prenomme.xcodeproj
```

### Tester les IAP en simulateur
Le scheme `Prenomme` lie automatiquement `Resources/Prenomme.storekit` (3 produits) — les achats fonctionnent sur simulator avec faux paiement instantané.

### Bypass Pro (DEBUG uniquement)
1. Réglages → tap 5× sur "Version" en moins de 3 s
2. Saisir le code dans le prompt
3. La section "Debug" apparaît → "Simuler Pro"

> En build Release, le menu Debug n'existe pas (compilation conditionnelle `#if DEBUG`).

### Tests
```bash
xcodebuild test -scheme Prenomme -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## Identifiants & déploiement

| | |
|---|---|
| Bundle ID | `com.sacha9955.prenomme` |
| Team ID | `Y9U6L9TB4B` |
| App Group | `group.com.sacha9955.prenomme` |
| iCloud Container | `iCloud.com.sacha9955.prenomme` |

Les Product IDs et toute la config IAP sont documentés dans [`AppStoreConnect/PRODUCT_IDS.md`](AppStoreConnect/PRODUCT_IDS.md).

### Submit App Store

1. **Préparation ASC** : suivre [`AppStoreConnect/SUBSCRIPTIONS_SETUP.md`](AppStoreConnect/SUBSCRIPTIONS_SETUP.md) si premier setup des subscriptions
2. **Metadata** : copier-coller depuis [`AppStoreConnect/metadata.md`](AppStoreConnect/metadata.md)
3. **Build production** :
   ```bash
   xcodebuild archive -project Prenomme.xcodeproj -scheme Prenomme \
     -configuration Release -destination 'generic/platform=iOS' \
     -archivePath build/archive/Prenomme.xcarchive

   xcodebuild -exportArchive -archivePath build/archive/Prenomme.xcarchive \
     -exportPath build/export -exportOptionsPlist /tmp/exportOptions.plist
   ```
4. **Upload** :
   ```bash
   xcrun altool --upload-app --type ios -f build/export/Prenomme.ipa \
     --apiKey "$ASC_API_KEY_ID" --apiIssuer "$ASC_API_ISSUER_ID"
   ```
5. **Submit** : ASC → Version 1.0.0 → Submit for Review

---

## Sources de données

- INSEE Prénoms (France)
- SSA / Social Security Administration (États-Unis)
- Wikidata (CC0)
- Étymologies enrichies via [Claude Haiku 4.5](https://www.anthropic.com/) (script `Scripts/reenrich_short_etymologies.py`)

---

## Confidentialité

Prénomme **ne collecte aucune donnée personnelle**. Pas d'analytics, pas de trackers, pas de SDK tiers, pas de pub.

Les favoris et notes utilisateur sont stockés localement via SwiftData. La synchronisation iCloud (optionnelle) se fait via le compte Apple de l'utilisateur, sans backend Prénomme.

[Politique de confidentialité](https://raw.githack.com/sacha9955/Prenomme-legal/main/privacy.html) · [Conditions d'utilisation](https://raw.githack.com/sacha9955/Prenomme-legal/main/terms.html)

---

## Documentation projet

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — Architecture détaillée, décisions techniques
- [`CHANGELOG.md`](CHANGELOG.md) — Historique des versions
- [`AUDIT_CODE_QUALITY.md`](AUDIT_CODE_QUALITY.md) — Audit qualité code
- [`APP_STORE_PRECHECKS.md`](APP_STORE_PRECHECKS.md) — Précheck pré-soumission
- [`AppStoreConnect/`](AppStoreConnect/) — Metadata + product IDs + guides submission
- [`.claude/`](.claude/) — Workspace Claude Code (CLAUDE.md, project-memory, checkpoints, quickstart)

---

## Licence

© 2026 Sacha Ochmiansky. Tous droits réservés.
