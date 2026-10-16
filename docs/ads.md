# Ads (AdMob)

- SDK: `google_mobile_ads`, consent via Google's User Messaging Platform (shown after onboarding, first time the main tabs appear). Max ad content rating PG.
- **Debug and profile builds use Google's public test ids.** The manifest also holds Google's **test application id** (`android/app/src/main/AndroidManifest.xml`, `com.google.android.gms.ads.APPLICATION_ID`).
- **Before the first release:**
  1. Create the app and three ad units (banner, interstitial, rewarded) in AdMob.
  2. Replace the application id in the manifest.
  3. Build with the unit ids:
     `flutter build appbundle --release --dart-define=AD_BANNER_ID=ca-app-pub-…/… --dart-define=AD_INTERSTITIAL_ID=… --dart-define=AD_REWARDED_ID=…`
     A release build without these defines shows **no ads** (by design, so test ads never ship).
  4. Publish `app-ads.txt` on the developer website, fill the Play Data safety form (advertising ID, ad interactions) and add a privacy policy link.
- Placement policy lives in `InterstitialPolicy` (tested in `test/srs_and_streak_test.dart`). Banner slot: `HomeShell`. Rewarded: streak repair on the Today screen.
- The app is not designed for children; do not enrol it in Families programmes.
