# Prénomme — Project Memory

> Décisions techniques et apprentissages persistants. Dates absolues.
> Source originelle : `~/.claude/projects/-Users-sachaochmiansky/memory/project_prenomme_*.md`

---

## Décisions architecturales (durables)

### Catalogue read-only via GRDB
**Décidé** : avril 2026.
- `Resources/names.sqlite` (45 274 prénoms) bundle-embedded, JAMAIS muté à l'exécution.
- Couche utilisateur séparée : SwiftData + CloudKit.
- **Why** : pas de risque de corruption catalogue, sync iCloud uniquement sur les données user (favoris, notes, settings).

### Algorithme phonétique : `pure` vs `vowels`
**Décidé** : avril 2026 (correctifs biais 'y').
- **`pure = {a,e,i,o,u}`** pour le SCORING (`lastVowelScore`, `alliterationScore start`, `elisionRisk lastName start`, `vowelDensity`).
- **`vowels` complet (inclut 'y')** pour LINGUISTIQUE (`syllableCount`).
- **Why** : sans cette règle, tous les prénoms en `-ynn` (Lynn, Flynn, Brynn) dominaient les résultats pour "Ochmiansky" via score `lastVowelScore` 1.0 au lieu de 0.5 neutre.
- **How to apply** : toute nouvelle fonction de scoring qui cherche des voyelles doit utiliser `pure`, pas `vowels`.

### IAP — StoreKit 2 + bypass DEBUG
**Décidé** : avril 2026.
- Produit unique non-consommable `prenomme.pro.lifetime` (8.99€).
- `product.purchase(confirmIn: scene)` avec `UIWindowScene` (requis iOS 17+).
- `setDebugForcePro(true)` persiste via UserDefaults `group.com.sacha9955.prenomme`.
- Toutes mutations de `PurchaseManager` via `await MainActor.run {}`.
- **Why** : `simctl` n'a pas StoreKit → bypass DEBUG nécessaire pour développement. JAMAIS exposer en production.
- **How to apply** : grep `setDebugForcePro|forcePremium|bypassIAP` avant chaque submit. Tous derrière `#if DEBUG`.

### Étymologies : prompt qualité 3 phrases
**Décidé** : 30 avril 2026.
- Run 3 final : 1 126 étymologies régénérées, 99.99% couverture (5 short restants : Kenari, Xiomora, Khiari×2, Luah).
- Prompt 3 phrases : (1) origine linguistique + racine, (2) sens littéral, (3) contexte culturel.
- ThreadPoolExecutor 10 workers, retry 3× (10s/30s/60s).
- **Why** : prompt compressé produisait des étymologies de 1-2 lignes ("Prénom masculin (Σάκα)" pour Sacha). Qualité prime sur tokens.
- **How to apply** : ne JAMAIS compresser le prompt système. Cache `data/cache/reenrich_etymology_cache.json`.

---

## Bugs résolus (référence)

| Date | Bug | Fix |
|---|---|---|
| avril 2026 | Biais prénoms `-ynn` dans compatibilité phonétique | Règle `pure` vs `vowels` (cf. décision ci-dessus) |
| 1er mai 2026 | `OnboardingView` PaywallView en ZStack overlay → dismiss cassé | Migration vers `.sheet` |
| 1er mai 2026 | `Info.plist` `UIBackgroundModes remote-notification` non déclaré | Suppression de l'entrée |
| 1er mai 2026 | `FavoriteService.isFavorite()` null-coalescing logic incorrecte | Correctif logique |

---

## Bugs connus restants
- *(aucun à 2026-05-02)*

---

## État courant (au 2026-05-02)
- **Version** : 1.0.0 (Build 1)
- **Statut** : Prête pour soumission App Store
- **Onboarding** : 3 écrans + paywall teaser (`.sheet`)
- **Audit qualité** : OK (cf. `AUDIT_CODE_QUALITY.md`)
- **Précheck App Store** : OK (cf. `APP_STORE_PRECHECKS.md`)

---

## Plugins / outils utilisés
- **GRDB.swift** 6.29.3+ — catalogue
- **NaturalLanguage** — phonétique locale
- **claude-haiku-4-5** (via `claude -p`) — backend ré-enrichissement étymologies
- **xcodegen** — génération `.xcodeproj` depuis `project.yml`

---

## À ne pas oublier avant submit
1. **Tester chaque lien legal** (Privacy URL, EULA) → `curl -I` doit retourner 200
2. **Grep bypass IAP** : `forcePremium|bypassIAP|setDebugForcePro|TEST_MODE` — tout doit être derrière `#if DEBUG`
3. **buildNumber strictement croissant** (sinon Apple bloque)
4. **`names.sqlite`** présent dans `Resources/` (postBuildScript copie dans bundle)
5. **Privacy Policy URL** valide dans App Store Connect
6. **EULA** : lien Apple Standard `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` ou EULA custom
