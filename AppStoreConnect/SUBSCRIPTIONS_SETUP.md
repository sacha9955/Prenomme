# Setup abonnements App Store Connect — Prénomme Pro

> Guide à exécuter dans App Store Connect avant build 2 / submit.
> 3 produits IAP : 1 lifetime existant + 2 abonnements à créer.

---

## État cible

| Produit | Type | Prix FR | Product ID | Statut |
|---|---|---|---|---|
| Pro Lifetime | Non-Consumable | 29,99 € | `prenomme.pro.lifetime` | ⚠️ À mettre à jour (était 8,99 €) |
| Pro Mensuel | Auto-Renewable Subscription | 2,99 € / mois | `prenomme.pro.monthly` | À créer |
| Pro Annuel | Auto-Renewable Subscription | 19,99 € / an | `prenomme.pro.yearly` | À créer |

**Note pricing** : le code (`PurchaseManager.fallback*Price` et le `Prenomme.storekit` local) utilise désormais 29,99 € / 2,99 € / 19,99 €. Si tu veux garder 8,99 € lifetime, modifie aussi `Services/PurchaseManager.swift:59` et le storekit avant build.

---

## Étape 1 — Mettre à jour le prix Lifetime (optionnel)

App Store Connect → Apps → Prénomme → **In-App Purchases** → `prenomme.pro.lifetime`

- Section **Pricing** → Edit Pricing
- Tier : **Tier 30** (29,99 €) — *ou conserve l'actuel si tu préfères*
- Save

---

## Étape 2 — Créer le subscription group

App Store Connect → Apps → Prénomme → **Subscriptions** → **Create Subscription Group**

| Champ | Valeur |
|---|---|
| Reference Name | `Prénomme Pro` |
| Group Display Name (FR) | `Prénomme Pro` |
| Group Display Name (EN) | `Prénomme Pro` |

→ Save

> ⚠️ Les 2 abonnements doivent être dans LE MÊME group (Apple impose un seul group actif par utilisateur ; permet l'upgrade/downgrade monthly ↔ yearly sans double facturation).

---

## Étape 3 — Créer `prenomme.pro.monthly`

Dans le group **Prénomme Pro** → **+ Create Subscription**

### Identifiers
| Champ | Valeur |
|---|---|
| Reference Name | `Pro Monthly` |
| Product ID | `prenomme.pro.monthly` |

### Subscription Duration
- **1 Month**

### Subscription Pricing
- France : **2,99 €** (Tier 3)
- Apply to all countries with conversion : ✅

### Localization (FR + EN minimum)

**FR :**
- Subscription Display Name : `Prénomme Pro — Mensuel`
- Description : `Accès Pro mensuel — favoris illimités, swipes illimités, étymologie complète, export PDF. Résiliable à tout moment.`

**EN :**
- Subscription Display Name : `Prénomme Pro — Monthly`
- Description : `Pro monthly access — unlimited favorites, unlimited swipes, full etymology, PDF export. Cancel anytime.`

### Review Information
- Screenshot : capture du **PaywallView** (1290×2796 ou 1284×2778 iPhone 6.7")
- Review notes (EN) :
  ```
  How to access: launch the app, complete onboarding, on Home tap any locked Pro feature (e.g. "Swipe", "Compatibility advanced filters") to open the paywall. The Monthly plan is selectable.
  ```

→ Save (status passe à **Ready to Submit**)

---

## Étape 4 — Créer `prenomme.pro.yearly`

Dans le même group **Prénomme Pro** → **+ Create Subscription**

### Identifiers
| Champ | Valeur |
|---|---|
| Reference Name | `Pro Yearly` |
| Product ID | `prenomme.pro.yearly` |

### Subscription Duration
- **1 Year**

### Subscription Pricing
- France : **19,99 €** (Tier 20)
- Apply to all countries with conversion : ✅

### Localization

**FR :**
- Subscription Display Name : `Prénomme Pro — Annuel`
- Description : `Accès Pro annuel — meilleur tarif (économisez 44 % vs mensuel). Favoris illimités, swipes illimités, étymologie complète, export PDF. Résiliable à tout moment.`

**EN :**
- Subscription Display Name : `Prénomme Pro — Yearly`
- Description : `Pro yearly access — best value (save 44% vs monthly). Unlimited favorites, unlimited swipes, full etymology, PDF export. Cancel anytime.`

### Review Information
- Screenshot : même capture que Monthly (PaywallView avec plan Annuel sélectionné)
- Review notes (EN) :
  ```
  How to access: launch the app, complete onboarding, on Home tap any locked Pro feature to open the paywall. The Yearly plan is the default selected option (with "SAVE 44%" badge).
  ```

→ Save

---

## Étape 5 — Subscription Group Order (important)

Dans le group **Prénomme Pro**, dans la section **Subscription Levels** :
- **Level 1** (top) : `prenomme.pro.yearly` (le meilleur tarif/feature)
- **Level 2** : `prenomme.pro.monthly`

> Apple recommande l'ordre du plus complet/cher au moins complet. Permet aux users de DOWNGRADE (yearly → monthly) à la fin de période, ou d'UPGRADE immédiatement (monthly → yearly avec proration).

---

## Étape 6 — Lier les 3 IAP à la version 1.0.0 (build 2)

App Store Connect → Apps → Prénomme → **App Store** → version 1.0.0 (préparation build 2)
- Section **In-App Purchases and Subscriptions** → **Edit**
- Cocher : `prenomme.pro.lifetime`, `prenomme.pro.monthly`, `prenomme.pro.yearly`
- Save

> ⚠️ Sans ça, Apple rejette le build : **Guideline 2.1(b)** "Apps with auto-renewable subscriptions must include all subscription products in the binary submission".

---

## Étape 7 — Paid Apps Agreement + Tax/Banking

Vérifier dans **Agreements, Tax, and Banking** :
- ✅ **Paid Applications Agreement** signé et **Active**
- ✅ Banking info renseigné
- ✅ Tax forms complétés (au moins France)

> Sans ça, les abonnements ne se vendent pas et Apple peut rejeter (déjà arrivé sur BabyCompanion — cf. memory `project_babycompanion_apple_rejection.md`).

---

## Étape 8 — Test sandbox

Sur iPhone réel :
1. Réglages → App Store → **Sandbox Account** → ajouter un compte test (créé dans ASC → Users and Access → Sandbox Testers)
2. Lancer Prénomme build 2 (TestFlight ou Xcode Run)
3. Ouvrir paywall → choisir `Annuel` → "Démarrer (19,99 €)"
4. Sandbox prompt → confirmer avec le compte sandbox
5. Vérifier : retour sur app, `isPro = true`, paywall dismiss, gates débloqués

> En sandbox, le renouvellement annuel est accéléré : 1 an = 1 heure réelle.

---

## Checklist finale avant submit build 2

- [ ] `prenomme.pro.lifetime` : prix mis à jour à 29,99 € (ou code aligné sur 8,99 €)
- [ ] `prenomme.pro.monthly` créé, status **Ready to Submit**
- [ ] `prenomme.pro.yearly` créé, status **Ready to Submit**
- [ ] Subscription group ordering : Yearly > Monthly
- [ ] Les 3 IAP cochés dans la version 1.0.0 build 2
- [ ] Screenshot paywall iPhone 6.7" attaché à chaque IAP (review)
- [ ] Paid Apps Agreement actif
- [ ] Test sandbox OK : achat Yearly → isPro = true → dismiss
- [ ] Test sandbox OK : achat Monthly → idem
- [ ] Test sandbox OK : achat Lifetime → idem
- [ ] Test sandbox OK : Restore → si déjà acheté, isPro reste true
