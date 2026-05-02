# Prénomme — Remplissage du formulaire App Store Connect

> Toutes les valeurs ci-dessous sont prêtes à copier-coller dans App Store Connect.
> Mise à jour : 2026-05-01 — version 1.0.0 (build 1).

---

## ⚠️ AVANT DE CRÉER L'APP — Vérifications côté Developer Portal

Avant que App Store Connect te propose le bon Bundle ID dans le dropdown :

1. Va sur <https://developer.apple.com/account/resources/identifiers/list>
2. Vérifie que **2 App IDs** existent :
   - ✅ `com.sacha9955.prenomme` (l'app principale)
   - ✅ `com.sacha9955.prenomme.widget` (l'extension widget)
3. Vérifie que **App Group** `group.com.sacha9955.prenomme` existe
4. Vérifie que **iCloud Container** `iCloud.com.sacha9955.prenomme` existe

Si l'un manque, crée-le **avant** de créer l'app dans App Store Connect.

Le compte Apple Developer doit être actif et le Team ID est : **`Y9U6L9TB4B`**.

---

## 1. Création de l'app — Étape "New App"

Dans App Store Connect → **My Apps → + → New App**, remplis :

| Champ | Valeur à saisir |
|---|---|
| **Platform** | iOS |
| **Name** | `Prénomme` |
| **Primary Language** | `French (France)` |
| **Identifiant de lot (Bundle ID)** | ✅ **`XC com sacha9955 prenomme — com.sacha9955.prenomme`** *(le PREMIER de la liste — PAS celui qui finit par `.widget`)* |
| **UGS / SKU** | `prenomme-2026-001` |
| **User Access** | `Full Access` |

> 🔴 **Important sur le Bundle ID** : tu choisis l'app principale (`com.sacha9955.prenomme`).
> Le bundle `com.sacha9955.prenomme.widget` est l'extension widget — elle est embarquée dans l'app principale et ne donne **PAS** lieu à une fiche App Store séparée. Ne jamais le sélectionner ici.

> 🔴 **Important sur l'UGS (SKU)** : c'est ton identifiant interne, libre. `prenomme-2026-001` est un bon choix court et stable. Une fois saisi, **il ne peut plus être modifié** — donc choisis-le bien.

---

## 2. App Information (onglet App Information)

| Champ | Valeur |
|---|---|
| **Subtitle (FR)** | `Trouvez le prénom parfait` *(30 caractères max)* |
| **Subtitle (EN)** | `Find the perfect baby name` *(30 caractères max)* |
| **Privacy Policy URL** | `https://raw.githack.com/sacha9955/Prenomme-legal/main/privacy.html` |
| **Category — Primary** | `Lifestyle` |
| **Category — Secondary** | `Reference` |
| **Content Rights** | `Does Not Use Third-Party Content` |
| **Age Rating** | 4+ *(remplir le questionnaire — toutes les réponses sont "None / No")* |

### Questionnaire Age Rating (à cocher)
- Cartoon or Fantasy Violence : **None**
- Realistic Violence : **None**
- Sexual Content or Nudity : **None**
- Profanity or Crude Humor : **None**
- Alcohol, Tobacco, or Drug Use : **None**
- Mature/Suggestive Themes : **None**
- Horror/Fear Themes : **None**
- Medical/Treatment Information : **None**
- Gambling : **None**
- Contests : **None**
- Unrestricted Web Access : **No**
- Made for Kids : **No** *(l'app cible les futurs parents adultes, pas les enfants)*

---

## 3. Pricing and Availability

| Champ | Valeur |
|---|---|
| **Price** | `Free` (tier 0) |
| **Availability** | `All countries and regions` *(ou liste personnalisée si tu veux limiter)* |

> L'app est gratuite avec achats intégrés. **Ne PAS** mettre l'app payante (tier ≠ 0), sinon les IAP seront bloqués par Apple.

---

## 4. Achats intégrés (3 produits) — Onglet "In-App Purchases"

> ⚠️ Crée les 3 produits avant la première soumission. Ils doivent être au statut "Ready to Submit" lors de la soumission.

### 4.1 Lifetime — Paiement unique

| Champ | Valeur |
|---|---|
| **Type** | `Non-Consumable` |
| **Reference Name** | `Prenomme Pro Lifetime` |
| **Product ID** | `prenomme.pro.lifetime` |
| **Cleared for Sale** | `Yes` |
| **Price** | Tier reflétant **29,99 €** (vérifier le tier Apple actuel — souvent Tier 30) |
| **Family Sharable** | `No` |

**Localisation FR :**
- Display Name : `Prénomme Pro — À vie`
- Description : `Accès à vie à toutes les fonctionnalités Pro : suggestions intelligentes, étymologie complète, prononciation audio, swipes et favoris illimités, export PDF, widget Pro. Paiement unique.`

**Localisation EN :**
- Display Name : `Prénomme Pro — Lifetime`
- Description : `Lifetime access to all Pro features: smart suggestions, full etymology, audio pronunciation, unlimited swipes and favourites, PDF export, Pro widget. One-time payment.`

**Review screenshot** : capture du PaywallView (640×920 px ou plus, max 5 MB)

---

### 4.2 Monthly — Abonnement mensuel

| Champ | Valeur |
|---|---|
| **Type** | `Auto-Renewable Subscription` |
| **Subscription Group** | `Prenomme Pro` *(à créer une fois, partagé avec l'annuel)* |
| **Reference Name** | `Prenomme Pro Monthly` |
| **Product ID** | `prenomme.pro.monthly` |
| **Subscription Duration** | `1 Month` |
| **Cleared for Sale** | `Yes` |
| **Price** | Tier reflétant **2,99 €** (souvent Tier 3) |
| **Family Sharable** | `No` |
| **Free Trial** | `None` |

**Localisation FR :**
- Display Name : `Prénomme Pro — Mensuel`
- Description : `Accès illimité à toutes les fonctionnalités Pro. Renouvellement mensuel, résiliable à tout moment.`

**Localisation EN :**
- Display Name : `Prénomme Pro — Monthly`
- Description : `Unlimited access to all Pro features. Monthly renewal, cancel anytime.`

---

### 4.3 Yearly — Abonnement annuel

| Champ | Valeur |
|---|---|
| **Type** | `Auto-Renewable Subscription` |
| **Subscription Group** | `Prenomme Pro` *(le même que le mensuel)* |
| **Reference Name** | `Prenomme Pro Yearly` |
| **Product ID** | `prenomme.pro.yearly` |
| **Subscription Duration** | `1 Year` |
| **Cleared for Sale** | `Yes` |
| **Price** | Tier reflétant **19,99 €** (souvent Tier 20) |
| **Family Sharable** | `No` |
| **Free Trial** | `None` *(optionnel : 7 jours d'essai gratuit pour booster les conversions)* |

**Localisation FR :**
- Display Name : `Prénomme Pro — Annuel`
- Description : `Accès illimité à toutes les fonctionnalités Pro. Renouvellement annuel — économisez 44% par rapport au mensuel.`

**Localisation EN :**
- Display Name : `Prénomme Pro — Annual`
- Description : `Unlimited access to all Pro features. Annual renewal — save 44% vs monthly.`

---

### 4.4 Subscription Group — Localisation (à remplir au niveau du groupe)

**FR :**
- Display Name : `Prénomme Pro`
- Description (App Store) : `Accès illimité à toutes les fonctionnalités avancées de Prénomme.`

**EN :**
- Display Name : `Prénomme Pro`
- Description (App Store) : `Unlimited access to all advanced Prénomme features.`

---

## 5. Version 1.0.0 — Préparation soumission

### 5.1 Promotional Text (170 chars max — modifiable sans nouvelle review)

**FR :**
```
Trouvez le prénom qui lui ressemble déjà. 45 000+ prénoms du monde entier, suggestions intelligentes, analyse phonétique, étymologie complète.
```

**EN :**
```
Find the name that already feels like them. 45,000+ names worldwide, smart suggestions, phonetic analysis, full etymology.
```

### 5.2 Description (4 000 chars max)

**FR :**
```
Prénomme vous aide à trouver le prénom parfait pour votre futur enfant.

Explorez plus de 45 000 prénoms français et internationaux, swipez vos coups de cœur et recevez des suggestions intelligentes selon vos goûts. 100% hors ligne — toutes les données sont sur votre appareil.

——— FONCTIONNALITÉS GRATUITES ———

• Explorer — Parcourez et filtrez par genre, origine, initiale ou nombre de syllabes
• Swiper — Découvrez de nouveaux prénoms en swipant (20 swipes/jour)
• Favoris — Sauvegardez jusqu'à 10 prénoms
• Prénom du jour — Une surprise chaque matin via un widget
• Origine et signification de chaque prénom

——— PRÉNOMME PRO ———

• Suggestions intelligentes — L'app analyse vos favoris et recommande des prénoms qui vous correspondent
• Analyse phonétique — Mesurez la compatibilité entre un prénom et votre nom de famille (allitération, rythme, élision)
• Étymologie complète — Découvrez l'histoire et le sens profond de chaque prénom
• Prononciation audio — Écoutez la diction exacte de chaque prénom
• Export PDF — Partagez votre liste de favoris dans un fichier élégant
• Widget Pro personnalisable — Filtrez par genre et origine
• Swipes et favoris illimités
• Filtres avancés (origines multiples, rangs de popularité)

3 formules au choix :
• À vie — paiement unique, jamais d'abonnement
• Annuel — économisez 44% par rapport au mensuel
• Mensuel — engagement souple, résiliable à tout moment

——— DONNÉES ———

Sources : INSEE Prénoms 2024, SSA (États-Unis), Wikidata CC0
Toutes les données sont stockées localement. Aucune connexion Internet n'est requise pour utiliser l'app.

——— CONFIDENTIALITÉ ———

Prénomme ne collecte aucune donnée personnelle. Vos favoris restent sur votre appareil (synchronisation iCloud optionnelle).

Pas de pub. Pas de tracking. Pas de surprise.
```

**EN :**
```
Prénomme helps you find the perfect first name for your baby.

Browse over 45,000 French and international names, swipe your favourites and get smart suggestions based on your taste. 100% offline — all data lives on your device.

——— FREE FEATURES ———

• Browse — Filter by gender, origin, initial or syllable count
• Swipe — Discover new names by swiping (20 swipes/day)
• Favourites — Save up to 10 names
• Name of the Day — A new surprise every morning via widget
• Origin and meaning for every name

——— PRÉNOMME PRO ———

• Smart suggestions — The app learns from your favourites and recommends names you'll love
• Phonetic analysis — Check the compatibility between a name and your surname (alliteration, rhythm, elision)
• Full etymology — Discover the history and deeper meaning behind every name
• Audio pronunciation — Hear how each name sounds
• PDF export — Share your shortlist as a beautifully formatted file
• Customisable Pro widget — Filter by gender and origin
• Unlimited swipes and favourites
• Advanced filters (multiple origins, popularity rankings)

Choose your plan:
• Lifetime — one-time payment, no subscription
• Annual — save 44% vs monthly
• Monthly — flexible, cancel anytime

——— DATA ———

Sources: INSEE Prénoms 2024, SSA (United States), Wikidata CC0
All data is stored locally. No internet connection is required to use the app.

——— PRIVACY ———

Prénomme collects no personal data. Your favourites stay on your device (optional iCloud sync).

No ads. No tracking. No surprises.
```

### 5.3 Keywords (100 chars max — séparés par des virgules **sans espace** après la virgule)

**FR :**
```
prénom,bébé,grossesse,naissance,liste,choix,origine,signification,étymologie,phonétique,futur parent
```

**EN :**
```
baby name,pregnancy,name finder,first name,French names,name meaning,name origin,newborn,etymology
```

### 5.4 Support URL (obligatoire)
```
https://raw.githack.com/sacha9955/Prenomme-legal/main/support.html
```
> Si ce fichier n'existe pas encore, crée-le dans le repo `Prenomme-legal` (page minimale avec ton email de contact).

### 5.5 Marketing URL (optionnel)
Laisse vide ou utilise la même que la Privacy Policy.

### 5.6 What's New (4 000 chars max — pour v1.0.0)

**FR :**
```
Bienvenue sur Prénomme — la première version officielle.

• Plus de 45 000 prénoms du monde entier, 100% hors ligne
• Mode Explorer avec filtres puissants (genre, origine, syllabes, initiale)
• Mode Swipe pour découvrir des prénoms par instinct
• Suggestions intelligentes Pro qui apprennent de vos favoris
• Analyse phonétique Pro pour la compatibilité avec votre nom
• Étymologie complète Pro pour l'histoire de chaque prénom
• Widget « Prénom du jour » pour l'écran d'accueil

Merci d'être parmi les premiers utilisateurs ! Pour toute remarque : sacha.ochmiansky@gmail.com
```

**EN :**
```
Welcome to Prénomme — the official 1.0 release.

• Over 45,000 names from around the world, 100% offline
• Explorer mode with powerful filters (gender, origin, syllables, initial)
• Swipe mode to discover names by instinct
• Smart suggestions Pro that learn from your favourites
• Phonetic analysis Pro for surname compatibility
• Full etymology Pro for the story behind every name
• "Name of the Day" widget for your home screen

Thanks for being among the first to try Prénomme!
For feedback: sacha.ochmiansky@gmail.com
```

---

## 6. Screenshots requis (iPhone 6.9" obligatoire pour iOS 17.5+)

| # | Écran à capturer | Légende suggérée FR | Légende EN |
|---|---|---|---|
| 1 | Onboarding — Welcome (écran 1) | « Trouvez le prénom qui lui ressemble déjà » | "Find the name that already feels like them" |
| 2 | HomeView — suggestions Pro visibles | « Des suggestions intelligentes selon vos goûts » | "Smart suggestions based on your taste" |
| 3 | SwipeView — carte en cours | « Swipez pour trouver votre prénom » | "Swipe to find your name" |
| 4 | NameDetailView — étymologie + phonétique | « Tout savoir sur chaque prénom » | "Discover every detail" |
| 5 | PaywallView — tableau Gratuit vs Pro | « Choisissez votre formule Pro » | "Choose your Pro plan" |

**Spécifications techniques** :
- iPhone 6.9" : 1320×2868 px (iPhone 16 Pro Max / iPhone 17 Pro Max)
- Format : PNG ou JPEG
- Pas de transparence
- Pas de status bar simulée — utilise celle de l'OS (heure 9:41)

> Astuce : utilise le simulateur iPhone 17 Pro Max et `xcrun simctl io <UDID> screenshot screen.png` après avoir mis l'heure à 9:41 avec `xcrun simctl status_bar <UDID> override --time "9:41"`.

---

## 7. App Review Information

### 7.1 Sign-In Information
> Cocher : **« Sign-in required: NO »** (l'app ne nécessite aucun compte)

### 7.2 Contact Information
| Champ | Valeur |
|---|---|
| First name | `Sacha` |
| Last name | `Ochmiansky` |
| Phone number | *(numéro mobile au format international, ex: +33 6 XX XX XX XX)* |
| Email | `sacha.ochmiansky@gmail.com` |

### 7.3 Notes pour l'équipe de review (anglais — Apple les attend en anglais)

```
Prénomme is a baby-name discovery app for expecting parents.

— No sign-in / account required: the app is fully usable without authentication.
— No internet connection required: all 45,000+ names are bundled in the app (read-only SQLite via GRDB).
— iCloud is OPTIONAL: used only to sync the user's favourites across their own devices via SwiftData + CloudKit. Disabling iCloud falls back to local-only storage with no data loss or feature loss.
— No third-party SDKs, no advertising, no analytics, no tracking.

In-App Purchases:
- prenomme.pro.lifetime (Non-Consumable, 29.99 €) — one-time purchase, lifetime Pro access.
- prenomme.pro.monthly (Auto-Renewable Subscription, 2.99 €/month, group "Prenomme Pro").
- prenomme.pro.yearly (Auto-Renewable Subscription, 19.99 €/year, group "Prenomme Pro").
The user picks ONE of these three. They unlock the same Pro feature set.

Data sources:
- INSEE (open data, France)
- SSA (open data, US Social Security Administration)
- Wikidata (CC0)
All names and meanings are public-domain or open-licensed.

Restore Purchases: paywall has a clearly labeled "Restaurer les achats" button calling AppStore.sync().

Privacy: NSPrivacyTracking is false. The PrivacyInfo manifest declares only purchase history (linked to the user, no tracking) and the standard UserDefaults / FileTimestamp APIs (with the official Apple-required reasons CA92.1 / C617.1).
```

### 7.4 Attachment (optionnel mais recommandé)
Joindre une courte vidéo de démo (30 secondes) montrant : onboarding → Explorer → Swipe → Détail → Paywall.

---

## 8. Version & Build

| Champ | Valeur |
|---|---|
| **Version** | `1.0.0` |
| **Build** | `1` *(ce sera reconnu automatiquement après upload via Xcode)* |
| **Copyright** | `© 2026 Sacha Ochmiansky` |
| **Trade Representative Contact (UE)** | Remplis tes coordonnées dans **App Store Connect → Account → Agreements, Tax, and Banking → Trader information** *(obligatoire depuis février 2024 pour vendre en UE)* |

---

## 9. Privacy / Data Collection (onglet App Privacy)

> Apple te fait remplir un questionnaire de collecte de données. Réponses correctes pour Prénomme :

### Question : "Do you or your third-party partners collect data from this app?"
→ **Yes** *(tu collectes Purchase History via StoreKit, c'est inévitable)*

### Data Types collected

| Type | Linked to user | Tracking | Purpose |
|---|---|---|---|
| **Purchase History** | ✅ Yes | ❌ No | App Functionality |

→ Toutes les autres catégories (Contact Info, Health, Location, etc.) : **Not Collected**

### Conformément au PrivacyInfo manifest :
- **Tracking** : NO
- **Third-party tracking** : NO
- **Data linked to user identity** : Purchase History only
- **Data used for app functionality only** : Purchase History

---

## 10. Order de soumission — Checklist final

Avant d'appuyer sur "Submit for Review" :

- [ ] App créée avec le bon Bundle ID (`com.sacha9955.prenomme`)
- [ ] SKU saisi (`prenomme-2026-001`)
- [ ] 3 IAPs créés et au statut "Ready to Submit"
- [ ] Subscription Group "Prenomme Pro" créé et localisé
- [ ] Description FR + EN remplies
- [ ] Keywords FR + EN remplis
- [ ] Promotional Text FR + EN remplis
- [ ] Privacy Policy URL active *(tester l'URL dans un navigateur)*
- [ ] Support URL active
- [ ] 5+ screenshots iPhone 6.9" uploadés
- [ ] Age Rating questionnaire complété (4+)
- [ ] App Privacy questionnaire complété
- [ ] Trade Representative info renseignée (UE/France)
- [ ] App Review Notes en anglais collées
- [ ] Build uploadé via Xcode (Archive → Distribute → App Store Connect)
- [ ] Build sélectionné dans la version 1.0.0
- [ ] Pricing : Free
- [ ] Availability : tous pays (ou liste choisie)
- [ ] Copyright `© 2026 Sacha Ochmiansky`

---

## 11. Notes finales

- **Si tu vois "Pending Developer Release"** après approbation Apple : tu peux release manuellement quand tu veux (recommandé pour coordonner avec une éventuelle communication).
- **Première soumission** : compte ~24 à 72 h de review. Les soumissions suivantes sont souvent < 24 h.
- **Si Apple rejette** : tu peux répondre via Resolution Center, ne pas re-soumettre depuis zéro. Tu disposeras des Notes for Reviewer pour fournir des précisions.
- **Important** : le scheme par défaut "Prenomme" charge la config StoreKit locale. Pour l'archive de soumission, **utilise le scheme "Prenomme Sandbox"** (pas de config StoreKit locale) ou fais l'archive avec scheme "Prenomme" mais en mode Release (la config StoreKit locale n'est appliquée qu'en Debug).
