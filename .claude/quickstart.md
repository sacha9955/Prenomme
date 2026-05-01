# Prénomme — Quickstart

## Lancer en local
```bash
xcodegen   # régénère Prenomme.xcodeproj depuis project.yml
open Prenomme.xcodeproj
# Cmd+R dans Xcode (utilise Prenomme.storekit pour bypass IAP DEBUG)
```

## Lancer via simctl (sans StoreKit)
```bash
xcodebuild -workspace Prenomme.xcworkspace -scheme Prenomme \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build
xcrun simctl install booted /path/to/Prenomme.app
xcrun simctl launch booted com.sacha9955.prenomme
# Note : bypass DEBUG actif (passe directement Pro)
```

## Build production
```bash
xcodebuild archive -workspace Prenomme.xcworkspace -scheme Prenomme \
  -configuration Release \
  -archivePath /tmp/Prenomme.xcarchive

# exportOptions.plist
cat > /tmp/exportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>Y9U6L9TB4B</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath /tmp/Prenomme.xcarchive \
  -exportPath /tmp/Prenomme-export \
  -exportOptionsPlist /tmp/exportOptions.plist
```

## Submit (déléguer à agent `appstore`)
```bash
xcrun altool --validate-app --type ios -f /tmp/Prenomme-export/Prenomme.ipa \
  --apiKey "$ASC_API_KEY_ID" --apiIssuer "$ASC_API_ISSUER_ID"

xcrun altool --upload-app --type ios -f /tmp/Prenomme-export/Prenomme.ipa \
  --apiKey "$ASC_API_KEY_ID" --apiIssuer "$ASC_API_ISSUER_ID"
```

## Tests
```bash
xcodebuild test -workspace Prenomme.xcworkspace -scheme Prenomme \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Re-enrichissement étymologies
```bash
python3 Scripts/reenrich_short_etymologies.py \
  --threshold 100 --priority-only --parallel 10 --batch-size 30 --yes
```

## Fichiers clés
- `App/PrenommeApp.swift` — entry point, ModelContainer init, PurchaseManager init
- `Services/PurchaseManager.swift` — StoreKit 2 @Observable
- `Services/PhoneticAnalyzer.swift` — scoring compatibilité (utilise `pure` set)
- `Services/NameDatabase.swift` — GRDB wrapper, toutes requêtes catalogue
- `Models/SwiftData/*` — Favorite, Note, UserSettings (CloudKit-compatible)
- `Views/Pro/PaywallView.swift` — paywall principal (`.sheet`)
- `Resources/names.sqlite` — catalogue 45k+ prénoms (read-only)
- `data/raw/*.csv` — sources brutes (gitignored)

## Identifiants
- Bundle : `com.sacha9955.prenomme`
- Team : `Y9U6L9TB4B`
- App Group : `group.com.sacha9955.prenomme`
- IAP product : `prenomme.pro.lifetime`
