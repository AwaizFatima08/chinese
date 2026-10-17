#!/usr/bin/env bash
# Builds the signed Play bundle with the real AdMob unit ids.
# Ids live in .secrets/ad-units.env (AD_BANNER_ID, AD_INTERSTITIAL_ID, AD_REWARDED_ID).
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .secrets/ad-units.env; set +a
: "${AD_BANNER_ID:?}" "${AD_INTERSTITIAL_ID:?}" "${AD_REWARDED_ID:?}"
flutter build appbundle --release \
  --dart-define=AD_BANNER_ID="$AD_BANNER_ID" \
  --dart-define=AD_INTERSTITIAL_ID="$AD_INTERSTITIAL_ID" \
  --dart-define=AD_REWARDED_ID="$AD_REWARDED_ID" "$@"
