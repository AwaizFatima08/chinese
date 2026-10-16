# Release checklist

1. `flutter analyze` and `flutter test` green.
2. Real AdMob ids (see `ads.md`); bump `version:` in `pubspec.yaml` (build number must increase).
3. Signing: create an upload keystore (outside git, e.g. `.secrets/`), write `android/key.properties`:
   ```
   storeFile=../../.secrets/upload.keystore
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```
   Both paths are gitignored. Without `key.properties` the release build is debug-signed: never upload that.
4. `flutter build appbundle --release --dart-define=AD_BANNER_ID=… --dart-define=AD_INTERSTITIAL_ID=… --dart-define=AD_REWARDED_ID=…`
5. Test the release APK on the A12 (`flutter build apk --release`, same defines) including a lesson, speaking, writing and an ad.
6. Store listing: `store/play_icon_512.png`; feature graphic and screenshots still to make; content rating questionnaire; Data safety (ads, no account); privacy policy URL; attribution is in the About screen (CC-CEDICT CC BY-SA, Tatoeba CC BY, MIT, Arphic/LGPL).
