# ARCHITECTURE — Prénomme

## Vue d'ensemble

App iOS native 100% offline. Deux couches de persistance strictement séparées : GRDB (catalogue read-only) et SwiftData + CloudKit (données utilisateur). Aucun backend, aucun compte, aucune analytics.

---

## Stack technique

| Couche | Techno | Rôle |
|---|---|---|
| UI | SwiftUI | 100% SwiftUI, UIKit interdit sauf cas absolu |
| Catalogue | GRDB.swift | SQLite bundle-embedded, read-only |
| Données user | SwiftData + CloudKit | Favoris, notes, settings — sync iCloud native |
| IAP | StoreKit 2 | 1 seul IAP non-consommable `prenomme.pro.lifetime` |
| Phonétique | NaturalLanguage | Analyse locale, zéro réseau |
| Widgets | WidgetKit | Prénom du jour (basique gratuit + Pro personnalisable) |
| Export | PDFKit | Shortlist PDF, fonctionnalité Pro |

**iOS minimum : 17.5** (SwiftData stable + CloudKit + `@Observable`)

---

## Structure de fichiers

```
Prenomme/
├── App/
│   └── PrenommeApp.swift          # @main, ModelContainer init, PurchaseManager init
├── Models/
│   ├── SwiftData/
│   │   ├── Favorite.swift         # @Model: id, nameId, addedAt — all optional/defaulted
│   │   ├── Note.swift             # @Model: id, nameId, text, updatedAt
│   │   └── UserSettings.swift     # @Model: familyName, onboardingDone, swipeDailyReset
│   └── Domain/
│       ├── FirstName.swift        # struct (value type), mapped from GRDB row
│       ├── Gender.swift           # enum: male | female | unisex
│       └── Origin.swift           # enum ou typealias String selon richesse des données
├── Services/
│   ├── NameDatabase.swift         # Singleton GRDB wrapper — toutes les requêtes catalogue
│   ├── PhoneticAnalyzer.swift     # NaturalLanguage : compatibilité, rythme, allitération
│   ├── PurchaseManager.swift      # @Observable StoreKit 2, entitlements au démarrage
│   ├── PDFExporter.swift          # PDFKit, Pro seulement
│   └── DailyNameProvider.swift    # Prénom du jour (seed déterministe par date)
├── Views/
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Browse/
│   │   ├── BrowseView.swift
│   │   └── FilterSheet.swift
│   ├── Detail/
│   │   └── NameDetailView.swift
│   ├── Swipe/
│   │   └── SwipeView.swift
│   ├── Favorites/
│   │   └── FavoritesView.swift
│   ├── Compatibility/
│   │   └── CompatibilityView.swift
│   ├── Pro/
│   │   └── PaywallView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Resources/
│   ├── names.sqlite               # Bundle-embedded, JAMAIS modifié à l'exécution
│   └── Assets.xcassets
├── Widget/
│   ├── NameOfDayWidget.swift      # Gratuit : 1 taille, style imposé
│   └── NameOfDayWidgetPro.swift   # Pro : toutes tailles, personnalisable
├── Scripts/
│   └── import_names.py            # Génère names.sqlite depuis /data/raw/*.csv
└── Tests/
    ├── PrenommeTests/             # XCTest unitaires
    └── PrenommeUITests/           # XCTest UI
```

---

## Séparation des persistances (règle critique)

### GRDB — catalogue read-only
- `names.sqlite` compilé dans le bundle, jamais modifié à l'exécution
- Accessible uniquement via `NameDatabase` (singleton)
- `NameDatabase` ouvre la DB en mode `.readonly`
- Pas de migration, pas de versioning — si le catalogue change, on livre une nouvelle version app
- **Jamais synchronisé via CloudKit** (15k+ prénoms = trafic prohibitif, données publiques)

### SwiftData — données utilisateur
- `Favorite`, `Note`, `UserSettings` uniquement
- Container configuré avec `CloudKitDatabase.automatic` pour sync iCloud native
- **Contraintes impératives pour CloudKit** :
  - Tous les attributs : optionnels ou avec valeur par défaut
  - Zéro `@Attribute(.unique)` (CloudKit ne le supporte pas, crash silencieux en sync)
  - Relations : toujours optionnelles, `deleteRule` explicite (`.cascade` ou `.nullify`)
  - Pas de `@Transient` sur des propriétés nécessaires à la sync

---

## Modèles SwiftData (contraintes CloudKit)

```swift
// Exemple conforme CloudKit
@Model
final class Favorite {
    var id: UUID = UUID()
    var nameId: Int = 0          // référence GRDB id
    var addedAt: Date = Date()
    
    init(nameId: Int) {
        self.nameId = nameId
    }
}
```

Jamais :
```swift
@Attribute(.unique) var id: UUID  // ❌ crash CloudKit
var nameId: Int                    // ❌ sans default = crash sync
```

---

## CloudKit — Mode dégradé

Au démarrage de l'app, avant d'initialiser le `ModelContainer` :

```swift
let isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
let cloudKitConfig: ModelConfiguration.CloudKitDatabase = isICloudAvailable ? .automatic : .none
```

- iCloud disponible → `CloudKitDatabase.automatic` (sync normale)
- iCloud KO / non connecté → `CloudKitDatabase.none` (local-only, données sur l'appareil)
- Si local-only → toast discret au premier lancement : "Sync iCloud désactivée — vos données restent sur cet appareil."
- SwiftData ne throw pas lors du switch — comportement natif, zéro crash

**Compteur swipes** : stocké dans `UserDefaults(suiteName: "group.com.sacha9955.prenomme")` uniquement. **Jamais** dans SwiftData ni CloudKit. Clés :
- `swipes_date` : String date du jour (format `yyyy-MM-dd`)
- `swipes_count` : Int

Reset : si `swipes_date != today`, remettre `swipes_count = 0`. Comparaison via `Calendar.current` (timezone locale).

---

## PurchaseManager (StoreKit 2)

```
@Observable PurchaseManager
├── isPro: Bool                     # source de vérité unique pour le gating
├── product: Product?               # produit StoreKit chargé
├── purchase() async throws         # déclenche l'achat
├── restore() async throws          # restaure les achats
└── Task { Transaction.updates }    # écoute background, mis en place au init
```

- `Transaction.currentEntitlements` vérifié à chaque lancement
- `isPro` propagé via `@Observable` → toutes les vues réagissent sans boilerplate
- Pas de RevenueCat, pas de wrapper tiers

---

## Gating freemium

| Feature | Gratuit | Pro |
|---|---|---|
| Favoris | **15 max** | Illimité |
| Mode swipe | **30/jour** (reset minuit local) | Illimité |
| Recherche + parcours catalogue | ✅ Complet | ✅ |
| Origine + signification (basique) | ✅ Gratuit | ✅ |
| Popularité (rang FR/US) | ✅ Gratuit | ✅ |
| Compatibilité phonétique avancée | 🔒 Pro | ✅ |
| Export PDF shortlist | 🔒 Pro | ✅ |
| Comparateur côte-à-côte (4 prénoms) | 🔒 Pro | ✅ |
| Widget personnalisable | 🔒 (style imposé) | ✅ (toutes tailles) |
| Suggestions intelligentes | 🔒 Pro | ✅ |

**Pattern UI Pro** : les features Pro sont **visibles mais grisées** avec un badge "Pro". Un tap sur une feature grisée ouvre directement `PaywallView` (sheet). Jamais de contenu caché — maximize la conversion.

Gating via `PurchaseManager.isPro` injecté en `@Environment`. Un seul point de vérité, pas de duplication.

---

## Schéma SQLite (GRDB)

```sql
CREATE TABLE names (
    id              INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    gender          TEXT CHECK(gender IN ('male','female','unisex')),
    origin          TEXT,
    origin_locale   TEXT,   -- BCP-47 pour TTS : fr-FR, ja-JP, ar-SA...
    meaning         TEXT,
    syllables       INTEGER,
    popularity_rank_fr INTEGER,
    popularity_rank_us INTEGER,
    themes          TEXT,   -- JSON array : ["nature","mythologie"]
    phonetic        TEXT    -- approximation IPA
);

CREATE INDEX idx_name   ON names(name);
CREATE INDEX idx_gender ON names(gender);
CREATE INDEX idx_origin ON names(origin);
CREATE INDEX idx_pop_fr ON names(popularity_rank_fr);
CREATE INDEX idx_pop_us ON names(popularity_rank_us);
```

### Phase d'import données
- **Jour 1-2 (MVP)** : 500 prénoms hardcodés en Swift pour débloquer le dev UI
- **Jour 3-4** : `scripts/import_names.py` consomme INSEE + SSA + Wikidata → génère `names.sqlite`
- Sources autorisées : INSEE (Etalab ✅), SSA (domaine public ✅), Wikidata CC0 ✅
- Source **interdite** : Behind the Name (licence non compatible)

---

## PhoneticAnalyzer (NaturalLanguage)

Analyses fournies (toutes locales, zéro réseau) :
- **Compatibilité avec nom de famille** : comptage syllabes, terminaison consonantique/vocalique, allitération
- **Surnoms potentiels** : troncature simple (< 3 syllabes)
- **Score rythme** : alternance accents toniques estimée

Exposé via `func analyze(_ firstName: FirstName, familyName: String) -> CompatibilityReport`

---

## DailyNameProvider (Widget)

Seed déterministe : `Int(date.timeIntervalSinceReferenceDate / 86400)` → index dans catalogue. Même prénom sur tous les devices le même jour, sans réseau.

---

## Ordre d'implémentation (10 jours)

| Jour | Livrable |
|---|---|
| 1 | Setup Xcode + SwiftData + CloudKit config + GRDB wrapper + 500 prénoms hardcodés |
| 2 | HomeView + BrowseView + NameDetailView + test sync CloudKit 2 devices |
| 3 | FavoritesView + SettingsView + OnboardingView |
| 4 | Script Python import + names.sqlite final intégré |
| 5 | SwipeView + CompatibilityView + PhoneticAnalyzer |
| 6 | PaywallView + StoreKit 2 + tests sandbox |
| 7 | Widgets + PDFExporter |
| 8 | Polish UI, animations spring, haptics, dark mode |
| 9 | Tests unitaires + UI + screenshots + App Preview |
| 10 | Build TestFlight + soumission App Store |

---

## Décisions d'architecture

| Décision | Choix | Raison |
|---|---|---|
| `@Observable` vs `ObservableObject` | `@Observable` | iOS 17+ minimum, moins de boilerplate, pas de `@Published` |
| Navigation | `NavigationStack` + sheet | Pattern standard iOS 17, pas de lib tierce |
| GRDB singleton | Oui | Une seule connexion DB read-only, accès depuis services/widgets |
| Pas de coordinator/router | Oui | App de taille moyenne, NavigationStack natif suffit |
| CloudKit sync | Automatique via SwiftData | Zéro code réseau custom, iCloud natif |
| Pas de Combine | Oui | `@Observable` + `async/await` couvrent tous les cas |

---

## Ce qui n'est PAS dans l'architecture

- Aucun backend, aucune API
- Aucun compte utilisateur custom
- Aucune analytics (RGPD-safe by construction)
- Aucune dépendance tierce hors GRDB.swift
- Aucun UIKit sauf si SwiftUI absolument insuffisant (cas non identifié à ce stade)
