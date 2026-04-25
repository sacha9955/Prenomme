#!/usr/bin/env bash
# Removes all installed builds of Prenomme from booted simulators.
# Run this before a fresh TestFlight-like install to avoid stale data.

set -euo pipefail

BUNDLE_ID="com.sacha9955.prenomme"

booted=$(xcrun simctl list devices --json \
  | python3 -c "
import json, sys
devs = json.load(sys.stdin)['devices']
ids = [d['udid'] for rts in devs.values() for d in rts if d.get('state') == 'Booted']
print('\n'.join(ids))
")

if [[ -z "$booted" ]]; then
  echo "No booted simulator found. Boot one first."
  exit 1
fi

while IFS= read -r udid; do
  echo "Uninstalling $BUNDLE_ID from $udid…"
  xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null && echo "  ✓ done" || echo "  — not installed, skipped"
done <<< "$booted"

echo "Cleanup complete."
