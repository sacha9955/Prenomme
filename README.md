# Prénomme

> "Trouvez le prénom qui lui ressemble déjà."

Application iOS native permettant aux futurs parents de trouver le prénom idéal pour leur bébé. 100% offline, zéro backend, zéro coût récurrent.

## Stack technique

| | |
|---|---|
| Langage | Swift 5.10+ |
| UI | SwiftUI |
| Persistance utilisateur | SwiftData + CloudKit |
| Catalogue prénoms | SQLite via GRDB.swift (read-only, bundle-embedded) |
| IAP | StoreKit 2 (1 IAP lifetime `prenomme.pro.lifetime`) |
| Phonétique | NaturalLanguage framework |
| Prononciation | AVSpeechSynthesizer (locale dynamique) |
| Widgets | WidgetKit |
| Export | PDFKit |

**iOS minimum** : 17.5 — iPhone uniquement (iPad en v2)

## Build

1. Ouvrir `Prenomme.xcodeproj` dans Xcode 16+
2. Sélectionner le scheme `Prenomme`
3. Pour tester les IAP : scheme → Run → Options → StoreKit Configuration → `Prenomme.storekit`
4. Build & Run sur simulateur ou device

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — Organisation du code, décisions techniques, contraintes SwiftData/CloudKit
- [CHANGELOG.md](CHANGELOG.md) — Historique des versions

## Licence

© 2026 Sacha. All rights reserved.
