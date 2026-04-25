# Changelog

## [Unreleased]

## [0.6.0] — 2026-04-25 — Jour 6 : Widget Pro, Export PDF & Liens profonds

### Added
- **ProNameWidget** (`Widget/ProNameWidget.swift`) — widget `AppIntentConfiguration` (iOS 17+), 3 tailles (small/medium/large) ; paramètres : `GenderFilter` (all/female/male/unisex), `DisplayMode` (nameOnly/nameAndOrigin/full), `origins` multi-select (27 origines via `OriginAppEntity`) ; déterminisme `day % pool.count` + reload `.after(midnight)` ; overlay Pro sage translucide pour non-abonnés
- **NameWidgetIntent** (`Widget/NameWidgetIntent.swift`) — `GenderFilter` / `DisplayMode` (`AppEnum`) + `OriginAppEntity` / `OriginEntityQuery` (`AppEntity` / `EntityQuery`)
- **NavigationRouter** (`App/NavigationRouter.swift`) — singleton `@Observable` ; `pendingNameId: Int?` + `showPaywall: Bool` pour le routage des liens profonds
- **PDFExporter** (`Services/PDFExporter.swift`) — A4 (595×842 pt), marges 56 pt, header/footer, pagination (3 prénoms page 1, 4 suivantes) ; bloc d'intro crème / bordure sage ; fiches avec strip gauche sage, capsule genre, rangs FR/US, séparateur
- **Liens profonds** `prenomme://name/{id}` et `prenomme://paywall` — traités dans `PrenommeApp.onOpenURL` → `NavigationRouter` → sélection d'onglet + navigation programmatique dans `BrowseView`
- **Pull-to-refresh** sur `BrowseView`

### Changed
- **PurchaseManager** — `isPro` persisté dans App Group `group.com.sacha9955.prenomme` ; `WidgetCenter.shared.reloadAllTimelines()` appelé à chaque changement d'entitlement
- **NameOfDayWidget** — restreint à `.systemSmall` (évite l'ambiguïté avec le widget Pro)
- **FavoritesView** — `exportPDF()` branché : `Task.detached` → `PDFExporter` → `ShareLink` ; overlay `ProgressView` + `.ultraThinMaterial` pendant la génération
- **ContentView** — sélection d'onglet piloée par `NavigationRouter.pendingNameId` ; paywall global via `router.showPaywall`
- **NameDetailView** — animation `.symbolEffect(.bounce)` + `withAnimation(.spring)` sur le cœur
- **FavoritesView** — `.animation(.spring)` sur la liste + `withAnimation(.spring)` sur la suppression swipe
- **HomeView** — haptic `.soft` sur les cartes d'origine
- **BrowseView** — `.symbolEffect(.bounce)` + `.contentTransition(.symbolEffect(.replace))` sur l'icône de filtre

### Tests (12 nouveaux)
- `PDFExporterTests` — 12 cas : en-tête `%PDF`, PDF non-vide sur liste vide, pagination 0/1/3/4/7/12/50 prénoms, intégrité de l'ordre, rangs et genres
- `WidgetTests` — 11 cas : déterminisme `nameForDate`, filtre genre feminin/masculin, filtre origine (réduction du pool, fallback pool complet), politique timeline midnight

## [0.5.0] — 2026-04-25 — Jour 5 : Analyse phonétique & Suggestions

### Added
- **PhoneticAnalyzer** (`Services/PhoneticAnalyzer.swift`) — 5 métriques phonétiques françaises : `syllableCount` (groupes vocaliques + règle du e-muet précédé d'une consonne), `alliterationScore` (consonnes d'attaque, distinction cluster simple vs. multiple), `rhythmScore` (table syllabique 2+2/2+3/…), `elisionRisk` (voyelle finale + h aspiré), `hardConsonantClash` (consonnes prononcées à la jonction) ; `CompatibilityScore` struct avec formule pondérée et verdict 4 niveaux
- **CompatibilityView** (`Views/Compatibility/CompatibilityView.swift`) — 5ème onglet "Compatibilité" (Pro-gaté) : saisie du nom de famille, score global avec jauge colorée, 4 métriques détaillées
- **ComparatorView** (`Views/Favorites/ComparatorView.swift`) — feuille de comparaison côte à côte jusqu'à 4 favoris (Pro-gaté depuis FavoritesView) : genre, origine, signification, syllabes, rangs FR/US, score phonétique ; sélection visuelle d'un prénom gagnant
- **SuggestionService** (`Services/SuggestionService.swift`) — moteur de suggestions basé sur les favoris : profil de goûts (top 3 origines, médiane syllabes, genre dominant), scoring par similarité (origine 40 %, syllabes 30 %, genre 20 %, popularité 10 %)
- **HomeView** enrichi — section "Suggestions pour vous" (Pro-gaté) avec bande horizontale de 10 prénoms + pourcentage de correspondance
- **FavoritesView** enrichi — bouton "Comparer" dans la barre de navigation ouvre ComparatorView (Pro-gaté)

### Tests (81 passés, 0 échecs)
- `PhoneticAnalyzerTests` — 33 cas : syllables (6), allitération (6), rythme (5), risque d'élision (5), choc de consonnes (4), score global (3), surnoms (4)
- `SuggestionServiceTests` — 17 cas : buildProfile (4), similarityScore (6), suggest (7)

### Fixed
- `syllableCount` : le e-muet final n'est déduit que s'il est précédé d'une consonne — "Marie" → 2 syllabes (correction), "Pierre" → 1 syllabe (inchangé)
- `alliterationScore` : un cluster consonantique complet identique (ex. "Str-/Str-") renvoie 1.0 ; une simple lettre partagée renvoie 0.85

## [0.3.0] — 2026-04-24 — Jour 3 : Navigation, Détail & Origines

### Added
- **OnboardingView** (`Views/Onboarding/OnboardingView.swift`) — 3 écrans PageTabView (bienvenue, fonctionnalités, nom de famille) ; gate `@AppStorage("hasSeenOnboarding")` dans `PrenommeApp` ; nom de famille sauvegardé dans `UserSettings` SwiftData
- **NameFilter** (`Services/NameFilter.swift`) — struct unifiée `Equatable` : genre, origines multi-select, syllabes (5 = "5+"), initiale, searchQuery, sortByPopularity
- **NameDatabase extensions** — `filtered(_ filter: NameFilter)` (SQL paramétré), `countByOrigin() -> [String: Int]`
- **FilterSheet** (`Views/Browse/FilterSheet.swift`) — bottom sheet : genre (segmented), origines (chips horizontal), syllabes, initiale, tri
- **BrowseView** (`Views/Browse/BrowseView.swift`) — `NavigationStack` + `.searchable` + filtre actif (icône filled) → `NameDetailView`
- **PronunciationService** (`Services/PronunciationService.swift`) — `@Observable` + `AVSpeechSynthesizer` + `SynthProxy` délégué
- **NameDetailView** (`Views/Browse/NameDetailView.swift`) — hero circulaire, signification, popularité FR/US, TTS, favori haptic, `ShareLink`, sections phonétique + similaires pro-gatées ; `FlowLayout` custom `Layout`
- **OriginService** (`Services/OriginService.swift`) — `@Observable` singleton, `OriginMeta` (27 origines, 2 couleurs pastel chacune, description, count), `countByOrigin()` mis en cache
- **OriginDetailView** (`Views/Browse/OriginDetailView.swift`) — header dégradé, filtre genre, liste paginée → `NameDetailView`
- **HomeView** redesigné — carte "Prénom du jour", section tendances horizontale, section "Parcourir par origine" (cartes 140×100pt)
- **FavoritesView enrichie** — swipe-to-delete, sort picker (date/alphabétique), compteur X/15, état vide CTA, export PDF pro-gaté
- **ContentView** — 4ème onglet "Explorer" (`BrowseView`)

### Tests (34 passés, 0 échecs)
- `OriginServiceTests` — 6 cas : non-vide, count > 0, 2 couleurs, description, unicité, cohérence avec DB
- UI tests mis à jour : `--skip-onboarding` launch arg + assertion nav bar "Prénomme"

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
