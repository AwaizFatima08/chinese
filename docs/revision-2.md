# Revision 2 (1.1.0, build 2): checklist before sending to Google Play

Not submitted yet. Version 1.0.0 (build 1) is in review.

## Build (done 2026-10-17: AAB built, 62.7 MB, versionCode 2; Play signing SHA-1 added to Firebase)
1. `google-services.json` is in place (copy in `.secrets/`); both SHA-1 fingerprints (upload and Play signing) are in Firebase.
2. `scripts/build_release.sh` produces `build/app/outputs/bundle/release/app-release.aab` (versionCode 2).
3. Test the release APK on a phone: sign in, finish a lesson, sign out/in, delete account.

## Play Console changes (when uploading 1.1.0)
- **Privacy policy URL**: `https://tools.homilabs.org/lingo15/privacy-policy` (the old `.../privacy#lingo15` still works).
- **Data safety** (update the form, it must match the policy):
  - Personal info: Email address, Name, User IDs. Collected, not shared. Purposes: App functionality, Account management. Required only if the user signs in (optional feature).
  - App activity: collected for app functionality (progress backup). Not shared.
  - Data encrypted in transit: yes. Account creation methods: OAuth (Google). Users can log in with accounts created outside the app: yes (Google).
  - Deletion: yes, with link `https://tools.homilabs.org/lingo15/delete-account`. Say the app also deletes data in-app.
  - Keep the AdMob rows (location, device IDs, app interactions, crash logs, diagnostics).
- **App access**: still "no part of the app is restricted" (sign-in is optional).
- Release notes: "New: optional Google sign-in to back up your progress and continue on another device. Your progress still works without an account."
- Account deletion: Play requires an in-app path and a web link for apps with accounts. Both exist.

## Already done
Firebase project, Google sign-in, Firestore database and rules, tools.homilabs.org pages, tests (84 passing).

## Test results (2026-10-17, release build 1.1.0+2 on the Galaxy Tab S9 FE and Samsung A12)
- Passed on the tablet with the real Firebase project: Google sign-in (account chooser and consent), first sync (Firestore got `shared` and `lang_zh`), restore after clearing app data (streak, minutes, learned word, lesson 1 all came back), sign out (progress stays), sign in again, delete account (Firestore collection empty, Authentication has no users, app back to signed out).
- A12: Settings section and account chooser work; cancelling is handled. Its Google accounts are other people's, so no sign-in there.
- Not tested: two devices syncing at the same time, the security rules against a second user, Play-installed build (Play-signing SHA-1 is registered).
- Optional polish: Google Auth Platform > Branding has no privacy-policy or terms link, so the consent screen shows none. Adding them needs `homilabs.org` as an authorised domain.
