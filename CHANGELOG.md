# Changelog

## [Unreleased]

## [0.2.0] — 2026-04-24 — Jour 2 : Freemium, Paywall & App Icon

### Added
- **PurchaseManager** (`Services/PurchaseManager.swift`) — StoreKit 2 singleton (`@Observable`), gère l'achat unique `prenomme.pro.lifetime`, la restauration (`AppStore.sync()`), et l'écoute des transactions en arrière-plan (`Transaction.updates`)
- **PaywallView** (`Views/Paywall/PaywallView.swift`) — écran premium Apple Design Award : hero terracotta→sage, tableau Free vs Pro (10 fonctionnalités), prix dynamique StoreKit, bouton "Restaurer les achats", footer légal "Paiement unique"
- **ProGateModifier** (`Views/Common/ProGateModifier.swift`) — ViewModifier `.proGated()` grisant le contenu non-Pro et affichant un badge capsule "Pro" ; tap → PaywallView en sheet
- **SwipeCounter** (`Services/SwipeCounter.swift`) — compteur quotidien dans UserDefaults (App Group `group.com.sacha9955.prenomme`), reset local timezone, limite 30 swipes/jour gratuit
- **FavoriteService** (`Services/FavoriteService.swift`) — CRUD favoris SwiftData avec limite 15 max (gratuit), `AddResult` enum, `toggle()` idempotent
- **App Icon** (`Resources/Assets.xcassets/AppIcon.appiconset/`) — 15 tailles iOS générées via `Scripts/GenerateAppIcon.swift` (CGBitmapContext opaque RGB, `noneSkipLast`, SF Pro Rounded Bold "P" sur dégradé terracotta→sage), `hasAlpha: no` vérifié
- **Logo source** (`Resources/Logo/logo-source.svg` + `AppIcon-1024.png`) — SVG éditorial + export PNG 1024×1024

### Tests (25 passés, 0 échecs)
- `SwipeCounterTests` — 7 cas : init, increment, limite, remaining, reset par date injectée
- `FavoriteServiceTests` — 11 cas : isFavorite, add/remove/toggle, limite free/pro, favoriteCount
- `NameDatabaseTests` — 7 cas existants (regression) : all, filter, search, byId, random, nameForDate, origins

### Fixed
- Widget `Info.plist` : `NSExtension` / `NSExtensionPointIdentifier` explicite (résout crash simulateur iOS 26 "extensionDictionary must be set")
- Test targets `GENERATE_INFOPLIST_FILE: YES` (résout erreur codesign manquant Info.plist)

---

## [0.1.0] — 2026-04-23 — Jour 1 : Fondations

### Added
- ARCHITECTURE.md : organisation du code, décisions techniques
- README.md : stack, build instructions, licence
- .gitignore Swift/Xcode complet
- XcodeGen `project.yml` : cibles Prenomme, PrenommeWidget, PrenommeTests, PrenommeUITests
- GRDB.swift 6.29.3 via SPM — wrapper `NameDatabase` lecture-seule + fallback HardcodedNames
- SwiftData `VersionedSchema` (SchemaV1) — `Favorite`, `UserSettings`, `SwipeRecord` ; plan de migration `PrenommeMigrationPlan`
- 500 prénoms hardcodés (`Services/HardcodedNames.swift`) avec genre, origine, signification, popularité FR/US, thèmes, phonétique
- Widget NameOfDay (`Widget/`) — `NameOfDayWidget` + `PrenommeWidgetBundle`, TimelineProvider 24 h
- StoreKit `.storekit` test file — produit `prenomme.pro.lifetime` 4,99 €
- `PrenommeApp.swift` — iCloud detection + fallback gracieux + toast
