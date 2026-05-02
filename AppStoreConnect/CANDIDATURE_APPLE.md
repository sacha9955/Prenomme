# Candidatures Apple — Prénomme

> Textes prêts à copier-coller pour les différents programmes Apple.
> Date de préparation : 2026-05-02. Version 1.0.0 build 4.

---

## 1. App Store Featuring (le plus courant — "Apps We Love" / "Today")

**Où soumettre** : App Store Connect → Apps → Prénomme → **App Store** → onglet **App Store Tab** → **Featuring** (ou directement via le formulaire https://developer.apple.com/contact/app-store/promote/)

### What is your app about? (1 sentence — pitch principal)
```
Prénomme aide les futurs parents à trouver le prénom idéal de leur enfant grâce à un catalogue de 45 000+ prénoms, des suggestions intelligentes basées sur leurs favoris, et une analyse phonétique de la compatibilité avec leur nom de famille — le tout 100 % offline et sans collecte de données.
```

### What's new or unique about it? (3-4 sentences — ce qui te distingue)
```
Prénomme se distingue par trois choix radicaux : zéro réseau (toutes les données sont embarquées dans l'app, pas de tracking, pas de pub), un algorithme phonétique local basé sur le framework NaturalLanguage d'Apple qui mesure la vraie compatibilité prénom/nom de famille (allitération, rythme, élision), et des étymologies enrichies à 99,99 % qui racontent l'origine, le sens et le contexte culturel de chaque prénom. L'expérience swipe ludique permet de découvrir de nouveaux prénoms en quelques secondes, et le widget "Prénom du jour" inspire à l'écran d'accueil. L'app s'adapte parfaitement au mode sombre et propose 3 formules d'achat (mensuel 2,99 € / annuel 19,99 € / à vie 29,99 €) sans aucune publicité ni dark pattern.
```

### Why should it be featured? (Use case angle — pourquoi c'est éditorialement intéressant)
```
Choisir le prénom de son enfant est l'une des décisions les plus émotionnelles et durables qu'un futur parent prend. La plupart des apps existantes sont saturées de publicités, demandent une connexion permanente, ou poussent des achats agressifs. Prénomme propose une alternative respectueuse : aucune donnée collectée, aucun tracker, des prix transparents, une expérience apaisante en mode sombre comme clair. C'est l'app que je voulais avoir quand ma compagne était enceinte. Idéale pour la catégorie Lifestyle / Apps We Love, et particulièrement pertinente en période de forte natalité (printemps).
```

### Target audience
```
- Futurs parents (premier ou nème enfant), 25-40 ans
- Couples en recherche de prénom mixte / international
- Parents soucieux de la confidentialité (pas de tracking)
- Public francophone principal, anglophone secondaire
```

### Key features (bullet list pour Apple)
```
• Catalogue de 45 000+ prénoms (sources INSEE + SSA + Wikidata CC0)
• Étymologies enrichies (origine + sens + contexte culturel)
• Analyse phonétique de compatibilité prénom/nom de famille (allitération, rythme, élision)
• Suggestions intelligentes basées sur les favoris
• Mode swipe pour découverte ludique (20/jour gratuit, illimité Pro)
• Widget "Prénom du jour" sur l'écran d'accueil
• Sync iCloud des favoris entre les appareils du même Apple ID
• 100 % offline — aucune connexion requise
• Mode sombre et clair adaptatifs
• Zéro publicité, zéro tracker, zéro SDK tiers
```

### Special hooks (intégrations Apple à mettre en avant)
- **WidgetKit** : widget "Prénom du jour" gratuit + widget Pro personnalisable (3 tailles)
- **CloudKit** : sync favoris entre iPhone/iPad du même Apple ID
- **NaturalLanguage** : algorithme phonétique 100 % local
- **StoreKit 2** : paywall conforme aux dernières guidelines (3 plans, restore, family sharing sur lifetime)
- **SwiftUI 100 %** : design natif, animations fluides, mode sombre adaptatif
- **Family Sharing** activé sur l'IAP lifetime
- **App Privacy Report** : profil "Data Not Collected" (clean record)

### Screenshots / vidéo
Voir `Screenshots/iPhone/` et `Screenshots/iPad/` (8 captures chacun, ordre commercial 01-08).

### Contact
- Sacha Ochmiansky — sacha.ochmiansky@gmail.com
- Bundle ID : com.sacha9955.prenomme
- App URL : https://apps.apple.com/app/prénomme (live après review)

---

## 2. Apple Small Business Program (réduit la commission de 30 % à 15 %)

**Où soumettre** : App Store Connect → **Agreements, Tax, and Banking** → **Apple Small Business Program** → **Apply Now**

### Conditions
- Revenus app < 1M USD sur l'année calendaire précédente : ✅
- Pas d'autre app rapportant > 1M USD : ✅ (à vérifier si tu as BabyCompanion qui rapporte)
- Activer pour toutes les apps de ton compte développeur

### Texte de candidature
*Le formulaire est principalement déclaratif (cocher les conditions), pas de description longue requise. Confirmer simplement :*
```
Legal entity name : Sacha Ochmiansky
Apple Developer Program account ID : (récupérer dans Account → Membership)

I confirm that:
☑ My business has earned less than 1M USD in proceeds in the prior calendar year
☑ I will not have any associated apps that have earned over 1M USD
☑ I agree to the Apple Small Business Program terms
```

### Effet
À partir du 1er janvier de l'année suivant l'enrôlement, **commission Apple = 15 %** au lieu de 30 % sur tous tes IAP. Concrètement pour Prénomme :
- Lifetime 29,99 € → tu touches 25,49 € au lieu de 20,99 €
- Annuel 19,99 € → 16,99 € au lieu de 13,99 €
- Mensuel 2,99 € → 2,54 € au lieu de 2,09 €

---

## 3. Apple Design Awards (annuel, juin — pour design exceptionnel)

**Où soumettre** : https://developer.apple.com/design/awards/ (formulaire ouvre généralement en avril/mai)

### Critères Apple
1. **Inclusivity** : accessibilité, multi-langue, multi-culturel
2. **Delight & Fun** : animations, interactions
3. **Innovation**
4. **Interaction**
5. **Social Impact**
6. **Visuals & Graphics**

### Pitch suggéré (300-500 mots)
```
Prénomme is a SwiftUI app that helps expecting parents find the perfect first name for their child — fully offline, zero tracking, zero ads.

What makes Prénomme stand out from a design perspective:

• A meticulously crafted dark mode where every color is defined as an adaptive Asset Catalog color set with light + dark variants. No hardcoded RGB values anywhere in the codebase — every surface uses a typed design system (`Color.brand`, `Color.genderFemale`, `Color.appSurfaceElevated`, etc.) ensuring perfect contrast in both modes.

• A swipe interface inspired by dating apps but reinterpreted for an emotional context: the card features a giant initial as a watermark on a gender-aware gradient (rose, blue, sage), three statistical tiles (letters, syllables, French popularity rank), and a culturally-rich etymology section. Drag interactions use SpringAnimation curves with proper Transaction.disablesAnimations to avoid the classic SwiftUI flicker when removing items.

• A phonetic compatibility analyzer powered entirely by Apple's NaturalLanguage framework — measuring alliteration, rhythm, and elision risks between a chosen first name and the user's surname. All computations happen locally in milliseconds, with no API calls.

• Three Family-aware Pro plans (monthly, yearly, lifetime) wired through StoreKit 2 with proper transaction handling, restore flow, and a graceful degradation path when products fail to load. Family Sharing is enabled for the lifetime tier per Apple guidelines.

• A gorgeous WidgetKit-powered home screen widget showing the "Name of the Day" — refreshed at midnight, locale-aware, with a Pro variant that lets users filter by gender and origin.

• Inclusive by design: 45,000+ names from French (INSEE), American (SSA), and international (Wikidata CC0) sources. Origins include Hebrew, Nordic, Japanese, Arabic, African, Slavic, and many more. Both genders + unisex labels are equally represented.

• A 3-screen onboarding that respects the user: skippable premium teaser, no aggressive paywall, no forced sign-up.

• Zero data collection. Zero third-party SDKs. Zero ads. The Apple Privacy Report shows a clean "Data Not Collected" badge — a rarity in the Lifestyle category.

Prénomme demonstrates that a deeply useful, emotionally resonant app can be built entirely on Apple's native frameworks (SwiftUI, SwiftData + CloudKit, GRDB, NaturalLanguage, AVFoundation, WidgetKit, StoreKit 2) without compromising on design quality or user privacy.
```

---

## 4. App Store Promotion via Apple Search Ads (différent — c'est de la pub)

Pas une "candidature" : tu paies pour apparaître en haut des résultats de recherche App Store. Setup via https://searchads.apple.com.

> Recommandation : ne pas lancer Search Ads avant d'avoir validé la conversion organique pendant ~2 semaines après le launch.

---

## 5. Apple Developer Stories / Press / Newsroom

**Où contacter** : appstorepromotion@apple.com (réservé aux apps featured ou approchées par Apple directement)

### Pitch presse (court — 100 mots)
```
Prénomme est une app iOS française dédiée au choix du prénom de bébé. Catalogue de 45 000 prénoms, étymologies enrichies, analyse phonétique avec le nom de famille — le tout 100 % hors-ligne, sans collecte de données, sans publicité. Conçue par un parent pour les parents, l'app propose 3 formules d'achat transparentes (mensuel, annuel, à vie) et un widget "Prénom du jour" sur l'écran d'accueil. Disponible en français et anglais sur l'App Store.

Contact presse : Sacha Ochmiansky — sacha.ochmiansky@gmail.com
```

---

## Conseils pratiques

1. **Featuring** : à soumettre au moins 4 semaines avant la date souhaitée de mise en avant. Apple privilégie les apps fraîches (release < 6 mois).
2. **Small Business Program** : à activer dès que possible — l'effet est rétroactif au 1er janvier de l'année d'enrôlement. Si tu enrôles en 2026, tu paies 15 % sur **tous** tes revenus 2026.
3. **Apple Design Award** : la deadline est généralement fin avril, soumets uniquement si l'app a au moins un point d'innovation marqué (ici : design system 100 % adaptatif + algo phonétique local + zéro data collection — c'est défendable).
4. **Toutes les soumissions** : fournir minimum **5 captures iPhone 6.7"** (déjà prêtes dans `Screenshots/iPhone/`).
5. **Évite** de candidater pour le Featuring si l'app n'est pas encore vivante sur le store — Apple veut voir des reviews et des données usage.

---

## Lien rapide vers les ressources

- Featuring submission : https://developer.apple.com/contact/app-store/promote/
- Small Business Program : https://developer.apple.com/app-store/small-business-program/
- Design Awards : https://developer.apple.com/design/awards/
- App Store Promotion artwork specs : https://developer.apple.com/app-store/marketing/guidelines/
