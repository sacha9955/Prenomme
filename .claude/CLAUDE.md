# Prénomme — .claude/CLAUDE.md

> Règles spécifiques à la session Claude Code pour ce projet.
> Hérite de `~/.claude/CLAUDE.md` (règles globales).

## Workflow obligatoire
1. Lire ce `CLAUDE.md` + `project-memory.md` + `checkpoints/latest.md`
2. `git status` puis ouvrir uniquement les fichiers concernés par la tâche
3. Travailler avec patches minimaux (pas de refactor global sans validation)
4. `/checkpoint` avant de quitter une session non triviale

## Agents prioritaires (par tâche)
- **Code Swift / SwiftUI** : `dev-ios` (haiku/sonnet selon complexité)
- **Build / Submit / TestFlight** : `appstore` (sonnet) — utilise skills `xcode-build-archive`, `appstore-submit`, `testflight-release`, `appstore-review-fix`
- **UI/UX upstream** : `design` (sonnet) avec skill `ui-ux-pro-max`
- **Code review post-modif** : `code-reviewer` (haiku, project-aware)
- **Bug debug** : skill `debug-session`
- **TDD** : `tdd-guide`

## Skills auto-déclenchées attendues
- `appstore-review-fix/` : sur questions Apple Guidelines, rejet, paywall, IAP compliance
- `xcode-build-archive/` : sur build production
- `appstore-submit/` : sur upload, validation IPA, soumission
- `tdd-workflow/` : sur nouvelles features
- `security-review/` : sur secrets, IAP, paywall

## Règles spécifiques projet
- **Phonétique** : toute fonction de scoring doit utiliser `pure = {a,e,i,o,u}`. `vowels` (inclut 'y') uniquement pour comptage syllabes (`syllableCount`).
- **IAP** : aucun bypass exposé en production. Tous les `setDebugForcePro` derrière `#if DEBUG`.
- **GRDB** : `Resources/names.sqlite` est read-only — JAMAIS muter à l'exécution.
- **CloudKit** : SwiftData @Model avec tous champs optionnels/defaultés (sinon crash sync).
- **Étymologies** : ne pas compresser le prompt 3 phrases.

## Commandes critiques
```bash
# Régénérer xcodeproj
xcodegen

# Build local (test)
xcodebuild -workspace Prenomme.xcworkspace -scheme Prenomme \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build

# Archive (release)
xcodebuild archive -workspace Prenomme.xcworkspace -scheme Prenomme \
  -configuration Release -archivePath /tmp/Prenomme.xcarchive

# Validate IPA avant upload
xcrun altool --validate-app --type ios -f /tmp/Prenomme.ipa \
  --apiKey "$ASC_API_KEY_ID" --apiIssuer "$ASC_API_ISSUER_ID"

# Upload
xcrun altool --upload-app --type ios -f /tmp/Prenomme.ipa \
  --apiKey "$ASC_API_KEY_ID" --apiIssuer "$ASC_API_ISSUER_ID"
```

## Ce qui n'est PAS dans ce projet
- Pas de backend / serveur (100% offline)
- Pas de compte utilisateur, pas d'analytics
- Pas de UIKit (sauf cas absolu : `activeScene()` pour StoreKit `confirmIn:`)
- Pas de `.storekit` config en submission release (uniquement Debug local)
