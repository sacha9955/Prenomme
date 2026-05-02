# Rapport Prénomme - Onboarding, Premium et Prechecks

Date : 2026-05-01
Build final : ✅ **SUCCEEDED** (xcodebuild iOS Simulator generic, configuration Debug)

## 1. Résumé

L'onboarding première utilisation a été enrichi (présentation app, fonctions principales, count de prénoms dynamique, teaser Premium discret avec « Découvrir Pro » / « Plus tard » / « Commencer »). Le PaywallView existant est réutilisé via `.sheet()`. Toutes les fonctions Premium ont été auditées : gating cohérent, paywall fonctionnel, aucun contournement UI détecté. Une correction App Store importante a été appliquée (`UIBackgroundModes: remote-notification` non utilisé retiré). Le projet compile sans erreur ni warning bloquant et est prêt pour soumission.

Backups effectués dans `~/.claude/backups/prenomme_onboarding_improvements/` (OnboardingView.swift, NameDatabase.swift).

## 2. Onboarding première utilisation

### Fichiers modifiés
- `Views/Onboarding/OnboardingView.swift` (+ refacto Premium teaser, count dynamique, paywall en sheet)
- `Services/NameDatabase.swift` (ajout `var totalNamesCount: Int`)
- `App/Info.plist` (retrait `UIBackgroundModes: remote-notification` non utilisé — cf. §5)

### Logique utilisée
- Flag de premier lancement : `@AppStorage("hasSeenOnboarding")` (déjà existant côté `PrenommeApp.swift`)
- `PrenommeApp.swift` route vers `OnboardingView` si `!hasSeenOnboarding`, sinon `ContentView`
- Argument CLI `--skip-onboarding` toujours disponible pour les tests

### Texte ajouté / mis à jour
- **Écran 1 (Welcome)** : « Prénomme — Trouvez le prénom qui lui ressemble déjà »
- **Écran 2 (Features)** :
  - Titre : « Tout ce qu'il vous faut »
  - Sous-titre dynamique : `\(totalNamesCount arrondi à la centaine)+ prénoms à explorer` (fallback : « Une vaste base de prénoms à explorer » si DB injoignable)
  - 5 features : recherche intelligente, favoris, prononciation audio, par origine, suggestions intelligentes
- **Écran 3 (Family Name + Premium)** :
  - Champ « Votre nom de famille » (optionnel, sert à la compatibilité phonétique)
  - Carte teaser Pro : 4 features Premium (prononciation, suggestions, étymologie, swipes illimités)
  - Bouton secondaire « Découvrir Pro » → ouvre `PaywallView` en `.sheet`
  - Bouton « Plus tard » → cache la carte teaser avec animation (sans avancer l'onboarding)
  - Bouton principal « Commencer » → `hasSeenOnboarding = true`, sauvegarde le nom de famille s'il est rempli

### Comportement au premier lancement
1. App démarre → `hasSeenOnboarding == false` → `OnboardingView` s'affiche
2. Utilisateur swipe entre les 3 écrans
3. Sur l'écran 3, il peut : (a) découvrir Pro via la sheet, (b) cacher le teaser, (c) saisir nom de famille, (d) cliquer « Commencer »
4. « Commencer » → `hasSeenOnboarding = true`, transition animée vers `ContentView`

### Comportement aux lancements suivants
- `hasSeenOnboarding == true` → `ContentView` directement, l'onboarding n'est plus jamais affiché
- Le PaywallView reste accessible depuis Settings et depuis chaque feature gatée (ProGateModifier)

## 3. Premium

### Vérification produit StoreKit
- StoreKit config locale : `Resources/Prenomme.storekit` (3 produits : `prenomme.pro.lifetime` 29,99 €, `prenomme.pro.monthly` 2,99 €, `prenomme.pro.yearly` 19,99 €)
- `PurchaseManager.shared.isPro` est calculé à partir de `Transaction.currentEntitlements` (lifetime ou subscription active)
- Bypass DEBUG via `setDebugForcePro(true)` (UserDefaults `group.com.sacha9955.prenomme`)

### Tableau de gating

| Fonction | Fichier | Accessible gratuit | Accessible Premium | Paywall OK | Correction appliquée |
|---|---|---|---|---|---|
| Favoris (limite) | `Services/FavoriteService.swift:31` | Oui (10 max) | Oui (illimité) | Oui (sheet via ProGate) | Aucune — déjà conforme |
| Swipes / jour | `Services/SwipeCounter.swift:5` + `Views/Swipe/SwipeView.swift:185` | Oui (20/jour) | Oui (illimité) | Oui (overlay déclenche paywall) | Aucune — déjà conforme |
| Recherche (résultats) | `Views/Browse/BrowseView.swift:77` | Oui (50 résultats max) | Oui (illimité) | Oui | Aucune — déjà conforme |
| Filtres avancés (initiale, syllabes) | `Views/Browse/BrowseView.swift` (proGated) | Non (teaser) | Oui | Oui | Aucune — déjà conforme |
| Suggestions intelligentes | `Views/Home/HomeView.swift:194` (`.proGated(.blur)`) | Non (blur + bouton « Découvrir Pro ») | Oui | Oui (sheet) | Aucune — déjà conforme |
| Étymologie complète | `Views/Browse/NameDetailView.swift:137` (`.proGated(.teaser)`) | Non (teaser cliquable) | Oui | Oui (sheet) | Aucune — déjà conforme |
| Analyses phonétiques | `Views/Browse/NameDetailView.swift:29` (`.proGated(.teaser)`) | Non (teaser cliquable) | Oui | Oui (sheet) | Aucune — déjà conforme |
| Compatibilité prénom + nom | `Views/Compatibility/CompatibilityView.swift:18` | Non (placeholder Pro) | Oui | Oui | Aucune — déjà conforme |
| Prononciation audio | Présent dans la feature table du paywall, déclenchée selon `purchase.isPro` | Non | Oui | Oui | Aucune |
| Export PDF | `Services/PDFExporter.swift` (appelé depuis FavoritesView quand `isPro`) | Non | Oui | Oui | Aucune |
| Widgets prénoms | Section gratuite (visible pour tous, ne nécessite pas Pro) | Oui | Oui | N/A | Aucune |
| Origine & signification | Section gratuite | Oui | Oui | N/A | Aucune |

**Aucune fonction gratuite n'est bloquée par erreur.** Aucun contournement UI détecté (les ProGateModifier appliquent un `disabled(true)` sur le contenu blurré).

### Paywall — points vérifiés
- ✅ 3 plans présentés (Annuel ÉCONOMISEZ 44%, Mensuel, À vie ZÉRO ABONNEMENT)
- ✅ Prix dynamique via `Product.displayPrice` avec fallback statique si StoreKit indisponible
- ✅ Bouton « Restaurer les achats » présent (`AppStore.sync()`)
- ✅ Bouton fermeture `xmark.circle.fill` (top-trailing)
- ✅ Disclosure auto-renouvelable (Apple-required) pour mensuel/annuel
- ✅ Liens « Politique de confidentialité » et « Conditions d'utilisation »
- ✅ Tableau Gratuit vs Pro clair (10 lignes)
- ✅ Dismiss automatique via `onChange(of: purchase.isPro)` dès achat ou restore réussi
- ✅ `confirmIn: UIWindowScene` correctement résolu (compatibilité iOS 17+)

## 4. Vérification code

### Erreurs / problèmes trouvés
- ❌ **Bug onboarding** : `PaywallView` était présenté via un `ZStack` overlay, ce qui rend `@Environment(\.dismiss)` inopérant et le close button silencieux → **corrigé** : remplacé par `.sheet(isPresented:)`.
- ❌ **Count statique** : « 500+ prénoms » était hardcodé alors que la base contient bien plus → **corrigé** : `NameDatabase.shared.totalNamesCount` arrondi à la centaine.
- ❌ **Bouton « Plus tard » sans action** : la closure était vide → **corrigé** : passe par `onDismiss` qui anime la disparition de la carte teaser.
- ❌ **`UIBackgroundModes: remote-notification`** déclaré dans `Info.plist` sans aucun code Push (`UNUserNotificationCenter`, `registerForRemote*` introuvables) → **corrigé** (retiré) : aurait risqué un rejet App Review (Guideline 5.1.1 / 2.5.1).

### Patterns sûrs vérifiés
- ✅ Aucun `print()` en production code
- ✅ Aucun `TODO`, `FIXME`, `placeholder`, `lorem` (le seul match « placeholders » est une variable SQL dans `NameDatabase.swift` — légitime)
- ✅ Toutes les mutations `PurchaseManager` via `await MainActor.run { ... }`
- ✅ `try?` partout pour les opérations DB et SwiftData (pas de force try sauf 2 cas justifiés)
- ✅ Mutations immutables côté StoreKit (`@Observable`, `private(set)` sur les vars exposées)

### Patterns acceptables (non corrigés — risque trop faible / hors scope)
- `try!` x 2 dans `Services/NameDatabase.swift:47-48` : fallback in-memory si bundle manque la DB. La création d'un `DatabaseQueue()` mémoire et la création d'une table sont des opérations qui ne peuvent pas raisonnablement échouer ; un `try?` masquerait simplement un crash silencieux.
- `fatalError` dans `App/PrenommeApp.swift:26` : si `ModelContainer` SwiftData ne peut être créé, l'app ne peut pas démarrer — `fatalError` est la réponse correcte.

### Risques restants
- **Resources/names_before_*.sqlite** (38 MB cumulés de DBs intermédiaires) — non inclus dans l'IPA (le `postBuildScript` ne copie que `names.sqlite`) mais bloat le repo Git. Recommandation : déplacer hors `Resources/` ou ajouter au `.gitignore`. Non critique pour la soumission.
- Le scheme `Prenomme` utilise la config StoreKit locale (`Resources/Prenomme.storekit`) en Debug : pour tester le sandbox réel App Store il faut utiliser le scheme `Prenomme Sandbox` (déjà créé, sans config StoreKit locale), avec un compte Sandbox Tester configuré dans Réglages > App Store du device/simulateur.

## 5. Prechecks App Store

| Point vérifié | Statut | Commentaire |
|---|---|---|
| Bundle ID | ✅ OK | `com.sacha9955.prenomme` (cohérent avec entitlements iCloud, App group, Widget) |
| Development Team | ✅ OK | `Y9U6L9TB4B` |
| Marketing Version | ✅ OK | `1.0.0` |
| Build Number | ✅ OK | `1` |
| Deployment target | ✅ OK | iOS 17.5 (cohérent avec features StoreKit 2 `confirmIn:`, SwiftData, `@Observable`) |
| App Icon 1024×1024 | ✅ OK | `App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` présent |
| App Icon — toutes tailles | ✅ OK | iPhone 20/29/40/60 @2x/@3x présents (iPad aussi déclarés, sans risque malgré `LSRequiresIPhoneOS`) |
| Launch Screen | ✅ OK | `UILaunchScreen` dict présent dans `Info.plist` |
| Permissions Info.plist | ✅ OK | Aucune permission demandée (pas de Camera/PhotoLibrary/Mic/Contacts/Location) — cohérent : app 100% offline, pas de tracking |
| Textes de permissions | ✅ N/A | Aucune permission requise |
| ATT (App Tracking Transparency) | ✅ N/A | `NSPrivacyTracking: false` dans `PrivacyInfo.xcprivacy` |
| Privacy Manifest | ✅ OK | `Resources/PrivacyInfo.xcprivacy` complet : tracking false, type `PurchaseHistory` déclaré (raison `AppFunctionality`), API `UserDefaults` (CA92.1) et `FileTimestamp` (C617.1) justifiées |
| `ITSAppUsesNonExemptEncryption` | ✅ OK | `false` (pas de crypto custom — utilise les standards iOS) |
| Background Modes | ✅ OK | **Corrigé** : `remote-notification` retiré (n'était pas utilisé) |
| Orientation | ✅ OK | Portrait uniquement (`UISupportedInterfaceOrientations`) |
| iPhone uniquement | ✅ OK | `LSRequiresIPhoneOS: true` |
| Multiscene | ✅ OK | `UIApplicationSupportsMultipleScenes: false` |
| iCloud / CloudKit entitlements | ✅ OK | `iCloud.com.sacha9955.prenomme` + `CloudKit` (cohérent avec SwiftData CloudKit `.automatic`) |
| App Group entitlement | ✅ OK | `group.com.sacha9955.prenomme` (partagé app + widget) |
| Widget Extension | ✅ OK | Bundle ID widget `com.sacha9955.prenomme.widget`, embed dans target Prenomme |
| IAP — produits déclarés en code | ✅ OK | `prenomme.pro.lifetime`, `prenomme.pro.monthly`, `prenomme.pro.yearly` (cohérents avec `Resources/Prenomme.storekit`) |
| IAP — chargement async + retry | ✅ OK | `loadProducts()` avec retry exponentiel (0s → 2s → 5s) et fallback prix |
| Paywall — prix visibles | ✅ OK | `displayPrice` StoreKit + fallback statique |
| Paywall — restore button | ✅ OK | `Restaurer les achats` → `AppStore.sync()` |
| Paywall — auto-renewal disclosure | ✅ OK | Texte légal Apple-conforme pour mensuel/annuel |
| Paywall — liens privacy/terms | ✅ OK | Liens fonctionnels vers `prenomme-legal/main/privacy.html` et `terms.html` |
| Aucun placeholder / lorem / TODO | ✅ OK | Code de production propre |
| Aucun `print()` en production | ✅ OK | Vérifié par grep |
| Aucune clé API hardcodée | ✅ OK | App 100% offline, pas de réseau autre que StoreKit + CloudKit + liens externes vers HTML statique |
| Aucun log sensible | ✅ OK | Pas de logging custom |
| Écran Premium clair | ✅ OK | Tableau comparatif Gratuit vs Pro, hiérarchie visuelle, prix lisibles |
| Onboarding non bloquant | ✅ OK | « Commencer » est toujours actif, le nom de famille est optionnel, le teaser Pro peut être masqué |
| Conformité générale | ✅ OK | Aucun contournement IAP, pas de payment bypass UI, pas de fonction gratuite cachée derrière le paywall |

## 6. Commandes exécutées

```bash
# Localisation projet
find /Volumes /Users -maxdepth 4 -type d -iname "*prenomme*"

# Audit Premium
grep -rn "proGated\|.isPro\|isPro " --include="*.swift" Services Views App
grep -rn "freeLimit\|freeSearchLimit\|hasSwipesRemaining" --include="*.swift" Services Views

# Audit code mort / dangerous
grep -rn "TODO\|FIXME\|placeholder\|lorem" --include="*.swift" Services Views App
grep -rn "print(" --include="*.swift" Services Views App
grep -rn "fatalError\|try!\|as!" --include="*.swift" Services Views App

# Build verification
xcodegen generate
xcodebuild -project Prenomme.xcodeproj -scheme Prenomme \
           -destination 'generic/platform=iOS Simulator' \
           -configuration Debug build
# → ** BUILD SUCCEEDED **
```

## 7. Prochaines actions recommandées

### Avant soumission
1. **Bumper le build** si re-soumission (`CURRENT_PROJECT_VERSION: "2"` dans `project.yml`).
2. **Créer les 3 produits IAP côté App Store Connect** s'ils n'existent pas déjà :
   - `prenomme.pro.lifetime` (Non-Consumable, 29,99 €)
   - `prenomme.pro.monthly` (Auto-Renewable Subscription, 2,99 €/mois, groupe « Prenomme Pro »)
   - `prenomme.pro.yearly` (Auto-Renewable Subscription, 19,99 €/an, même groupe)
3. **Tester le paywall en Sandbox réel** avec le scheme `Prenomme Sandbox` (sans config StoreKit locale) et un Sandbox Tester configuré dans Réglages > App Store du device.
4. **Tester le restore d'achat** sur device sandbox (achat → suppression app → réinstall → restore).
5. **Vérifier que l'onboarding ne s'affiche pas après réinstall + restore** (le `hasSeenOnboarding` est local au device, ce qui est correct).
6. **Captures d'écran App Store** : prévoir au moins 1 screen onboarding (écran Features) pour montrer la base de prénoms.

### Hygiène repo (non bloquant)
1. Nettoyer ou ignorer `Resources/names_before_*.sqlite` (~38 MB hors IPA mais dans Git).
2. Le scheme par défaut « Prenomme » charge la config StoreKit locale — confirmer que la pipeline CI/release utilise bien le scheme « Prenomme Sandbox » ou directement le build archive (pas de StoreKit local en production).

### Optionnel
- Ajouter un test unit `OnboardingViewTests` pour vérifier que `hasSeenOnboarding` passe à `true` après `finish()`.
- Ajouter un screenshot UI test pour les 3 écrans d'onboarding (avec et sans teaser dismissé).
- Considérer de remplacer la chaîne « Plus tard » par « J'y reviendrai » pour adoucir le wording (cosmétique).
