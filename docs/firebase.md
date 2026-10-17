# Firebase (optional sign-in and cloud backup)

Added in version 1.1.0 (build 2). The app works fully without it: if Firebase is not configured the account section is hidden.

## Project
- Firebase project **Lingo15**, id `lingo15`, number `1045378404555`, organisation homi55-org, Spark (free) plan. Google Analytics and Gemini are off.
- Android app `com.homilabs.lingo15`, app id `1:1045378404555:android:102d10f74290b95e130b4e`.
- Authentication: Google provider only (public name Lingo15, support email homi55@gmail.com). Web client id is in `lib/core/services/firebase_setup.dart`.
- Firestore: `(default)` database, Standard edition, location nam5 (US multi-region, permanent), production mode.
- Rules: `firebase/firestore.rules` (published). Each user can read, write and delete only `users/{uid}/backup/{shared | lang_<id>}`, each document under 900 KB. Everything else is denied.
- SHA-1 fingerprints registered in the Android app: upload key `6A:34:5E:A2:8D:0A:92:CF:DC:D3:A8:F6:EB:3C:AF:7E:C0:2D:C9:0B`.

## Still needed by hand
1. **`android/app/google-services.json`**: Firebase console > Project settings > Your apps > Lingo15 > `google-services.json`. It is gitignored. Without it the build works but sign-in is off. Keep a copy in `.secrets/`.
2. **Play app signing SHA-1**: Play Console > Test and release > App signing > copy "SHA-1 certificate fingerprint", then add it in Firebase > Project settings > Your apps > Add fingerprint. Without it Google sign-in fails for installs from Google Play (it works for the upload-key builds).

## Data model
One backup per user, three kinds of document, each `{json: <string>, updated: <server time>}`:
- `shared`: study days (day, seconds, lessons, reviews), streak freezes, chosen levels.
- `lang_<id>`: words `[id, box, dueDay, reps, lapses, lastDay]`, lessons `[id, stars, completedDay, attempts]`, characters written `{char: count}`.

## Sync rules (`lib/data/backup.dart`, tested in `test/backup_sync_test.dart`)
Local is the working copy. A sync reads the cloud copy, merges it with the device and writes back only what changed. A word keeps the most recently studied record; lessons keep best stars, latest day and most attempts; characters and day counters keep the larger value; freezes are united; this device's chosen level wins. Nothing is ever deleted by a merge. A language reset also deletes that language's cloud document. Sync runs after sign-in, 3 s after a session is saved, on app resume and from "Sync now".

## Account deletion
In the app: Settings > Backup and sync > Delete account and cloud data (removes the documents, then the Firebase user; re-asks Google sign-in if Firebase needs a recent login). Web page for Play and users: https://tools.homilabs.org/lingo15/delete-account (email request path). Deleting by hand: Firebase console > Authentication > delete user, and Firestore > `users/<uid>`.

## Pages
`https://tools.homilabs.org/lingo15/` (index, `privacy-policy.html`, `terms-of-use.html`, `delete-account.html`). Copies are in `docs/site/` and `/mnt/storage/projects/homilabs_tools/site/`.
