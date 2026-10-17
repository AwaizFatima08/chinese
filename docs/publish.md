# Publishing Lingo15 (state on 2026-10-17)

## Done
- Play Console app created: Lingo15: Chinese & German, com.homilabs.lingo15, console app id 4974727162267848659.
- App content: privacy policy, ads (yes), app access (none), content rating (Everyone / PEGI 3), target age 13+, data safety (AdMob data), advertising ID (yes), government (no), financial (none), health (none).
- Store listing, graphics, category Education, contact details. Text in `docs/play-listing.md`, graphics in `store/`.
- Production track: 178 countries targeted. Draft release "1.0.0 (1)" with release notes saved, **no bundle attached yet**.
- AdMob: app and three units created, ids in `.secrets/ad-units.env`. app-ads.txt live on homilabs.org and tools.homilabs.org.
- tools.homilabs.org: Lingo15 card, privacy and terms sections live (privacy URL `https://tools.homilabs.org/privacy#lingo15`).

## Submitted 2026-10-17
Bundle 1.0.0 (1) attached to the production release (full rollout, 178 countries) and all 11 changes submitted from Publishing overview. Google's quick checks run first, then review.

## Left (after review)
1. Watch Publishing overview and the developer email for the review result.
2. After the app is live: add the Play store link to the AdMob app (AdMob > Apps > Lingo15 > App settings) so ads serve fully, and swap "Coming soon" for the Play link on the tools.homilabs.org card.
3. Keep `android/key.properties` and `.secrets/lingo15-upload.keystore` safe. They are not in Git or Drive. Play App Signing allows an upload-key reset if lost.

## Browser notes
Hostinger File Manager and Play file inputs cannot take local files in the built-in browser. Workarounds used: Hostinger File Browser API from the page; images fetched from raw.githubusercontent.com (public repo). The 59 MB bundle was NOT pushed to the public repo (blocked as an out-of-place publication); upload it by hand from the file dialog.
