# Prénomme — Guide de soumission App Store

> Ce guide te permet de soumettre Prénomme sur App Store Connect **sans rien oublier** et en évitant les rejets les plus fréquents.
> Suis-le dans l'ordre.

---

## Avant de commencer

Vérifie que tu as :

- [x] Compte Apple Developer **payant** actif (99 $/an)
- [x] Identifiant équipe : **Y9U6L9TB4B**
- [x] Bundle ID `com.sacha9955.prenomme` enregistré dans `Certificates, IDs & Profiles`
- [x] App Group `group.com.sacha9955.prenomme` créé
- [x] iCloud Container `iCloud.com.sacha9955.prenomme` créé
- [ ] Repo `Prenomme-legal` activé sur GitHub Pages (Settings → Pages → main / root)
  - Vérifie : <https://sacha9955.github.io/prenomme-legal/privacy.html> doit s'afficher
- [ ] Méthode de paiement à jour dans App Store Connect → Agreements, Tax & Banking

---

## Étape 1 — Création de l'app dans App Store Connect

1. Va sur <https://appstoreconnect.apple.com>
2. **My Apps → + → New App**
3. Renseigne :
   - Platform : **iOS**
   - Name : **Prénomme**
   - Primary Language : **French (France)**
   - Bundle ID : `com.sacha9955.prenomme`
   - SKU : `prenomme-2026-001`
   - User Access : **Full Access**

---

## Étape 2 — Achats intégrés (3 produits)

> Menu : **My Apps → Prénomme → Features → In-App Purchases**

### 2.1 Lifetime (paiement unique)

| Champ | Valeur |
|---|---|
| Type | **Non-Consumable** |
| Reference Name | `Prenomme Pro Lifetime` |
| Product ID | `prenomme.pro.lifetime` |
| Cleared for Sale | **Yes** |
| Price | **Tier 30** (29,99 €) |
| Family Sharable | **No** |

**Localisation FR :**
- Display Name : `Prénomme Pro — À vie`
- Description : `Accès à vie à toutes les fonctionnalités Pro. Paiement unique.`

**Localisation EN :**
- Display Name : `Prénomme Pro — Lifetime`
- Description : `Lifetime access to all Pro features. One-time payment.`

**Review Information :**
- Screenshot : capture de la PaywallView avec le plan « À vie » sélectionné (1024×1024 ou plus)
- Review Notes : `Tap "À vie" then "Acheter (29,99 €)" to test the one-time purchase.`

### 2.2 Subscription Group (à créer **avant** les abonnements)

> Menu : **In-App Purchases → Subscription Groups → + Create**

- Reference Name : `Prenomme Pro`
- Localisation FR : Display Name `Prénomme Pro`
- Localisation EN : Display Name `Prénomme Pro`

### 2.3 Abonnement mensuel

| Champ | Valeur |
|---|---|
| Type | **Auto-Renewable Subscription** |
| Subscription Group | `Prenomme Pro` |
| Reference Name | `Prenomme Pro Monthly` |
| Product ID | `prenomme.pro.monthly` |
| Subscription Duration | **1 month** |
| Price | **Tier 3** (2,99 €) |
| Family Sharable | **No** |
| Free trial | (optionnel) — par exemple 3 jours gratuits |

**Localisation FR :**
- Display Name : `Prénomme Pro — Mensuel`
- Description : `Accès illimité à toutes les fonctionnalités Pro. Renouvellement mensuel.`

**Localisation EN :**
- Display Name : `Prénomme Pro — Monthly`
- Description : `Unlimited access to all Pro features. Monthly renewal.`

**Review Information :** screenshot + `Tap "Mensuel" then "Démarrer".`

### 2.4 Abonnement annuel

| Champ | Valeur |
|---|---|
| Type | **Auto-Renewable Subscription** |
| Subscription Group | `Prenomme Pro` |
| Reference Name | `Prenomme Pro Yearly` |
| Product ID | `prenomme.pro.yearly` |
| Subscription Duration | **1 year** |
| Price | **Tier 20** (19,99 €) |
| Family Sharable | **No** |

**Localisation FR :**
- Display Name : `Prénomme Pro — Annuel`
- Description : `Accès illimité à toutes les fonctionnalités Pro. Renouvellement annuel — économisez 44 % par rapport au mensuel.`

**Localisation EN :**
- Display Name : `Prénomme Pro — Annual`
- Description : `Unlimited access to all Pro features. Annual renewal — save 44 % vs monthly.`

> ⚠️ **Important Apple :** chaque IAP doit avoir un **screenshot** de l'écran qui le propose, sinon « Missing Metadata ».

---

## Étape 3 — App Information (général)

> Menu : **App Information**

| Champ | Valeur |
|---|---|
| Subtitle (FR) | `Trouvez le prénom parfait` |
| Subtitle (EN) | `Find the perfect baby name` |
| Privacy Policy URL | `https://sacha9955.github.io/prenomme-legal/privacy.html` |
| Privacy Choices URL | (laisser vide — pas applicable) |
| Category Primary | **Lifestyle** |
| Category Secondary | **Reference** |
| Content Rights | Coche : `No, it does not contain, show, or access any third-party content` |

### Age Rating

- **4+** (aucun contenu sensible)
- Toutes les questions du questionnaire : **None**

---

## Étape 4 — Pricing and Availability

- Price : **Free** (les fonctions Pro sont via IAP)
- Availability : **All countries** (ou adapter selon ta stratégie)
- Pre-Orders : non
- Distribution : **Public**

---

## Étape 5 — Préparer la version

> Menu : **+ Version or Platform → iOS → 1.0.0**

### 5.1 Description (FR)

Copier depuis `AppStoreConnect/metadata.md` (déjà rédigée, à mettre à jour avec les abonnements) :

```
Prénomme vous aide à trouver le prénom idéal pour votre enfant.

Explorez plus de 45 000 prénoms français et internationaux, swipez vos coups de cœur et recevez des suggestions personnalisées selon vos goûts.

——— FONCTIONNALITÉS GRATUITES ———

• Explorer — Parcourez et filtrez par genre, origine, initiale ou nombre de syllabes
• Swiper — Découvrez de nouveaux prénoms (20 swipes/jour)
• Favoris — Sauvegardez jusqu'à 10 prénoms
• Prénom du jour — Une surprise chaque matin en widget

——— PRÉNOMME PRO ———

3 formules au choix :
• Mensuel — 2,99 € / mois
• Annuel — 19,99 € / an (économisez 44 %)
• À vie — 29,99 € (paiement unique)

Inclus :
• Étymologie complète — l'histoire de chaque prénom
• Suggestions intelligentes — basées sur vos favoris
• Analyse phonétique avec votre nom de famille
• Comparateur (jusqu'à 4 prénoms)
• Export PDF, widget Pro personnalisable
• Swipes illimités, favoris illimités, filtres avancés

——— DONNÉES & CONFIDENTIALITÉ ———

Sources : INSEE 2024, SSA, Wikidata CC0
Toutes les données sont stockées localement.
Aucune donnée personnelle n'est collectée.
```

### 5.2 Keywords (FR, 100 char max)

```
prénom,bébé,grossesse,naissance,liste,choix,étymologie,signification,origine,prenom
```

### 5.3 Promotional Text (170 char max, modifiable sans review)

```
Découvrez 45 000+ prénoms et leur étymologie. Suggestions intelligentes, analyse phonétique, widget Pro. Pour les futurs parents.
```

### 5.4 Support URL

`https://sacha9955.github.io/prenomme-legal/`

### 5.5 Marketing URL

(optionnel, peut rester vide)

---

## Étape 6 — Captures d'écran (CRITIQUE)

### Tailles requises

- **iPhone 6.9"** (15 Pro Max, 16 Pro Max) — `1320 × 2868` portrait — **3 minimum, 10 max**
- **iPhone 6.5"** (11 Pro Max, XS Max) — `1242 × 2688` portrait — recyclable depuis 6.9"
- **iPad Pro 13"** (M4) — uniquement si l'app supporte iPad (check `UISupportedInterfaceOrientations_iPad`)

### Set recommandé (8 captures FR + EN)

1. **Home** avec la grille de catégories
2. **Browse** (filtres ouverts)
3. **NameDetail** d'un prénom avec étymologie visible
4. **Swipe** carte interactive
5. **Compatibility** (analyse phonétique avec un nom de famille)
6. **Paywall** avec les 3 plans visibles
7. **Suggestions Pro**
8. **Widget** sur l'écran d'accueil

### Génération automatique

Lance le script :
```bash
xcodebuild test -project Prenomme.xcodeproj -scheme Prenomme \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -only-testing:PrenommeUITests/ScreenshotTests
```
(à créer si besoin — sinon captures manuelles via simulateur)

---

## Étape 7 — Build (TestFlight + soumission)

```bash
# 1) Régénérer le projet
xcodegen generate

# 2) Archive (en vrai Xcode UI, recommandé)
#    Product → Destination → Any iOS Device (arm64)
#    Product → Archive
#    Organizer → Distribute App → App Store Connect → Upload

# 3) OU en CLI
xcodebuild archive \
  -project Prenomme.xcodeproj \
  -scheme Prenomme \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Prenomme.xcarchive

xcodebuild -exportArchive \
  -archivePath build/Prenomme.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist exportOptions.plist
```

> ⏱️ Patiente 10 à 60 min après l'upload pour que le build apparaisse dans TestFlight.

---

## Étape 8 — App Review Information

**Sign-in required ?** : **No**

**Demo account** : laisser vide (l'app n'a pas de login)

**Notes for the reviewer (CRITIQUE — éviter rejet IAP)** :

```
Prénomme est une app d'aide au choix du prénom. Trois IAP :
- prenomme.pro.lifetime (29,99 €, non-consumable, paiement unique)
- prenomme.pro.monthly (2,99 €/mois, auto-renewable)
- prenomme.pro.yearly (19,99 €/an, auto-renewable)

To test:
1. Open the app, accept the onboarding.
2. Tap any locked feature (e.g. "Suggestions" tab) or "Passez Pro" banner.
3. The paywall shows the 3 plans.
4. Tap a plan → "Démarrer" / "Acheter" → Apple sandbox payment sheet.
5. After purchase, all Pro features unlock immediately.
6. "Restaurer les achats" button is available on the paywall and in Settings.

Subscription terms (auto-renewable) are displayed below the buy button.
Privacy policy: https://sacha9955.github.io/prenomme-legal/privacy.html
Terms of use:   https://sacha9955.github.io/prenomme-legal/terms.html

The app does NOT collect any user data, has no account system,
and does not communicate with third-party servers.
```

**Contact information** :
- First Name : Sacha
- Last Name : Ochmiansky
- Phone : (ton numéro)
- Email : sacha.ochmiansky@gmail.com

---

## Étape 9 — Export Compliance

- **Does your app use encryption?** → **Yes** (HTTPS standard via WKWebView ?) ou **No** si pure local
- **Does your app qualify for any of the exemptions provided in Category 5, Part 2 of the U.S. Export Administration Regulations?** → **Yes**
- **Does your app implement any encryption algorithms that are proprietary or not accepted as standard by international standard bodies (IEEE, IETF, ITU, etc.)?** → **No**

> Cette config est déjà gérée via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO` dans `project.yml`. Pas de question posée par Apple.

---

## Étape 10 — Soumission

1. Sélectionner le build TestFlight
2. **Save** → vérifier que tous les warnings ont disparu
3. **Add for Review**
4. Choisir : **Manually release** (pour pousser le bouton après acceptation) ou **Automatically release**
5. Bouton : **Submit for Review**

---

## Anti-rejet — Checklist finale (à valider avant submit)

> Ce sont les rejets typiques que reçoivent les apps avec abonnements.

### Conformité technique
- [x] `PrivacyInfo.xcprivacy` présent dans le bundle ✅
- [x] `ITSAppUsesNonExemptEncryption = NO` dans Info.plist ✅
- [x] Bundle ID coherent partout (`com.sacha9955.prenomme`)
- [x] App icon 1024×1024 PNG **opaque** (pas d'alpha) ✅ — voir `App/Assets.xcassets/AppIcon.appiconset/`
- [ ] App fonctionne sur **iPhone Mini** (test simulateur SE 3rd gen)
- [ ] Pas de crash au lancement après réinstall (test : delete app + relaunch)
- [ ] Pas d'écran blanc bloquant si sans réseau

### Paywall (Guideline 3.1.2 — Subscriptions)
- [x] **Restaurer les achats** : bouton visible sur paywall + Settings ✅
- [x] **Privacy Policy URL** clic visible sur paywall ✅
- [x] **Terms of Use URL** clic visible sur paywall ✅
- [x] Texte auto-renouvellement complet sous le CTA ✅
- [x] Prix lisible (pas seulement « gratuit puis 9,99 €/mois » sans contexte) ✅
- [x] Possibilité de fermer le paywall sans payer (croix) ✅

### Métadonnées
- [ ] Description en FR + EN
- [ ] Subtitle ≤ 30 caractères
- [ ] Keywords ≤ 100 caractères (FR)
- [ ] 3+ screenshots par taille requise
- [ ] Privacy Policy URL accessible (200 OK) — vérifier curl
- [ ] Support URL accessible
- [ ] Description évoque clairement les 3 plans IAP et leurs prix
- [ ] Pas de mention de plateforme tierce concurrente (« comme sur Android », etc.)

### Privacy Nutrition Labels (App Privacy)
- Data Linked to You : **Purchases (App functionality)**
- Data Not Linked : aucune
- Tracking : **No**
- (Tout cohérent avec le `PrivacyInfo.xcprivacy`)

### Erreurs fréquentes (apprises de l'expérience)
1. ❌ **« Guideline 3.1.2 — Missing subscription terms »** → fixé : la PaywallView affiche maintenant le texte complet sous chaque plan auto-renouvelable
2. ❌ **« Guideline 5.1.1 — Missing privacy policy »** → fixé : URL valide active sur GitHub Pages
3. ❌ **« Guideline 2.1 — App crashes »** → vérifier sur iPhone SE 3rd gen + iPhone 16 Pro
4. ❌ **« Guideline 4.0 — Design — Generic experience »** → la PaywallView est très différenciée visuellement, OK
5. ❌ **« Missing or invalid IAP screenshot »** → chaque IAP doit avoir une capture en 1024×1024 minimum
6. ❌ **« Encryption export compliance »** → géré via `ITSAppUsesNonExemptEncryption = NO`

### Sandbox testing pré-soumission
1. Créer un **Sandbox Tester** (App Store Connect → Users and Access → Sandbox)
2. Sur le simulateur, scheme **Prenomme Sandbox** (sans `.storekit`)
3. Tester : achat lifetime, achat mensuel, achat annuel
4. Tester : restore purchases
5. Tester : annulation depuis Réglages iOS

---

## Étape 11 — Après acceptation

- Tag git : `git tag -a v1.0.0 -m "App Store launch" && git push --tags`
- Notes de version visibles uniquement après mise en production
- Monitor : **App Store Connect → Sales and Trends** + **Subscriptions** (rétention, conversion)

---

## Liens utiles

- App Store Review Guidelines : <https://developer.apple.com/app-store/review/guidelines/>
- Subscription guidelines : <https://developer.apple.com/app-store/subscriptions/>
- Privacy Manifest doc : <https://developer.apple.com/documentation/bundleresources/privacy_manifest_files>
- Required Reason API list : <https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api>
