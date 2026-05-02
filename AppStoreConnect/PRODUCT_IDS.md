# Identifiants produits IAP — Prénomme

> Source de vérité unique pour tous les Product IDs de Prénomme.
> Toute modification ici doit être répercutée dans :
> - `Services/PurchaseManager.swift` (constantes statiques)
> - `Resources/Prenomme.storekit` (config StoreKit locale Xcode)
> - `Prenomme.storekit` (root, miroir du Resources/)
> - App Store Connect → Apps → Prénomme → In-App Purchases / Subscriptions

---

## Tableau récapitulatif

| Produit          | Type                          | Product ID                  | Prix FR      | Reference Name | Internal ID                 | Subscription Group |
|------------------|-------------------------------|-----------------------------|--------------|----------------|-----------------------------|--------------------|
| Pro **À vie**    | Non-Consumable                | `prenomme.pro.lifetime`     | **29,99 €**  | Pro Lifetime   | `prenomme_pro_lifetime_001` | n/a                |
| Pro **Mensuel**  | Auto-Renewable Subscription   | `prenomme.pro.monthly`      | **2,99 €/mois** | Pro Monthly | `prenomme_pro_monthly_001`  | `Prénomme Pro` (`21500001`) |
| Pro **Annuel**   | Auto-Renewable Subscription   | `prenomme.pro.yearly`       | **19,99 €/an**  | Pro Yearly  | `prenomme_pro_yearly_001`   | `Prénomme Pro` (`21500001`) |

> ⚠️ Le **subscription group** doit être unique pour les 2 abonnements (Apple impose un seul group actif par utilisateur — permet l'upgrade/downgrade monthly ↔ yearly sans double facturation).

---

## Subscription Group

| Champ                | Valeur          |
|----------------------|-----------------|
| Reference Name       | `Prénomme Pro`  |
| Group ID (Xcode)     | `21500001`      |
| Display Name (FR)    | `Prénomme Pro`  |
| Display Name (EN)    | `Prénomme Pro`  |

**Order in group (Subscription Levels)** :
1. **Level 1 (top)** : `prenomme.pro.yearly` (le plus complet/avantageux)
2. **Level 2** : `prenomme.pro.monthly`

---

## Détails par produit

### `prenomme.pro.lifetime` — À vie (Non-Consumable)

| Champ                   | Valeur                                                           |
|-------------------------|------------------------------------------------------------------|
| Type                    | Non-Consumable                                                   |
| Family Shareable        | ✅ true                                                          |
| Prix                    | 29,99 € FR (Tier 30)                                             |
| Display Name (FR)       | `Prénomme Pro — À vie`                                           |
| Display Name (EN)       | `Prénomme Pro — Lifetime`                                        |
| Description (FR)        | Accès illimité à toutes les fonctionnalités de Prénomme : favoris illimités, swipes illimités, widget Pro et plus encore. |
| Description (EN)        | Unlimited access to all Prénomme features: unlimited favorites, unlimited swipes, Pro widget and more. |

### `prenomme.pro.monthly` — Mensuel (Auto-Renewable)

| Champ                   | Valeur                                                           |
|-------------------------|------------------------------------------------------------------|
| Type                    | RecurringSubscription                                            |
| Period                  | 1 Month (`P1M`)                                                  |
| Family Shareable        | ❌ false                                                         |
| Prix                    | 2,99 €/mois FR (Tier 3)                                          |
| Display Name (FR)       | `Prénomme Pro — Mensuel`                                         |
| Display Name (EN)       | `Prénomme Pro — Monthly`                                         |
| Description (FR)        | Accès Pro mensuel — favoris illimités, swipes illimités, étymologie complète, export PDF. Résiliable à tout moment. |
| Description (EN)        | Pro monthly access — unlimited favorites, unlimited swipes, full etymology, PDF export. Cancel anytime. |
| Group Number            | 1                                                                |

### `prenomme.pro.yearly` — Annuel (Auto-Renewable)

| Champ                   | Valeur                                                           |
|-------------------------|------------------------------------------------------------------|
| Type                    | RecurringSubscription                                            |
| Period                  | 1 Year (`P1Y`)                                                   |
| Family Shareable        | ❌ false                                                         |
| Prix                    | 19,99 €/an FR (Tier 20) — économise 44 % vs mensuel              |
| Display Name (FR)       | `Prénomme Pro — Annuel`                                          |
| Display Name (EN)       | `Prénomme Pro — Yearly`                                          |
| Description (FR)        | Accès Pro annuel — meilleur tarif (économisez 44 % vs mensuel). Favoris illimités, swipes illimités, étymologie complète, export PDF. Résiliable à tout moment. |
| Description (EN)        | Pro yearly access — best value (save 44% vs monthly). Unlimited favorites, unlimited swipes, full etymology, PDF export. Cancel anytime. |
| Group Number            | 2                                                                |

---

## Bundle / Identifiers généraux

| Item                    | Valeur                                |
|-------------------------|---------------------------------------|
| Bundle ID               | `com.sacha9955.prenomme`              |
| Team ID                 | `Y9U6L9TB4B`                          |
| App Group               | `group.com.sacha9955.prenomme`        |
| StoreKit Config Identifier | `D9B3A1E4-5F72-4C8B-9D01-234E56789ABC` |

---

## Utilisation dans le code

```swift
// Services/PurchaseManager.swift — source unique des constantes
static let lifetimeID: String = "prenomme.pro.lifetime"
static let monthlyID:  String = "prenomme.pro.monthly"
static let yearlyID:   String = "prenomme.pro.yearly"

// Accès dans la UI
PurchaseManager.shared.lifetimeProduct  // Product? (StoreKit)
PurchaseManager.shared.monthlyProduct
PurchaseManager.shared.yearlyProduct
PurchaseManager.shared.isPro            // true si lifetime OU subscription active
```

### Fallback prices (UI quand Product non chargé)

```swift
static let fallbackLifetimePrice: String = "29,99 €"
static let fallbackMonthlyPrice:  String = "2,99 €"
static let fallbackYearlyPrice:   String = "19,99 €"
```

---

## Checklist cohérence (à vérifier avant chaque submit)

- [ ] `Services/PurchaseManager.swift` constants matchent les Product IDs ci-dessus
- [ ] `Resources/Prenomme.storekit` contient les 3 produits avec les bons IDs
- [ ] `Prenomme.storekit` (root) miroir du `Resources/`
- [ ] App Store Connect : les 3 produits créés et liés à la version
- [ ] Subscription group Order : Yearly > Monthly
- [ ] Paid Applications Agreement actif (sinon achats refusés)
- [ ] Sandbox testé : achat des 3 plans → `isPro = true`, restore OK
- [ ] Screenshot review attaché à chaque IAP (PaywallView 6.7")
