# LingoDaily — learn languages in 15 minutes a day

Flutter **Android** app (package `com.homilabs.lingodaily`, never change after the first Play upload). Two languages ship: Chinese (HSK 1–6) and German (CEFR A1–C2); built to host more. Free, supported by AdMob ads. Working title: change `android:label`, `app_en.arb` (`appName`) and the icon script if renamed.

## Locations
- Root: `/mnt/storage/projects/Chinese`
- Local backup: `/mnt/storage/project_backups/Chinese_Backup/`
- GitHub: `AwaizFatima08/chinese` (public)
- Google Drive folder id: `1x041WOlOutqVFM0MU0uJXa1xGP-_5IRU` (rclone remote `gdrive`)
- Backup: `bash scripts/backup.sh` (tar + git push + Drive sync; commit first)

## Design rules (locked)
- **15 minutes a day, hard ceiling.** Lessons are 4–11 min, built from short steps; at 15 minutes of study today the lesson runner suggests stopping (`dailyCapSeconds` in `lesson_screen.dart`). Daily goal choices are 5/10/15 only.
- **Language packs.** Everything language-specific lives in `assets/content/<id>/` and the `LanguagePack` metadata (`pack.json`). App code never mentions Chinese except through the pack (TTS/STT locale, romanization label, tones, stroke writing). See `docs/add-a-language.md`.
- **Verbal teaching.** The teacher voice is the device TTS (`core/services/speaker.dart`); the learner's speech is checked with on-device recognition (`listener.dart`) and judged by sound (`PinyinLookup`), with a self-check fallback when recognition is unavailable.
- **Ads:** banner only on the four main tabs; interstitial only on the lesson-complete screen, never after the first lesson of the day, at most one per two lessons and 4 minutes apart (`InterstitialPolicy`, `AdGate`); rewarded ad only to repair a missed-day streak. Debug builds use Google's test ids; **release builds show no ads unless real ids are passed with `--dart-define`** (`docs/ads.md`).
- Strings are in `lib/l10n/app_en.arb`, generated from the table in `scripts/gen_arb.py`. Edit the table, run `python3 scripts/gen_arb.py && flutter gen-l10n`.

## Code map (`lib/`)
- `core/`: `providers.dart` (composition root), `services/` (speaker, listener, ad_service, system_settings), `theme/`, `util/pinyin.dart`, `widgets/`.
- `data/`: SQLite (`app_database.dart`, `ProgressRepository` interface with SQLite and in-memory versions), `srs.dart` (Leitner boxes), `settings.dart`.
- `languages/`: models, `LanguageContent` loader, `PinyinLookup` (segmenting, speech match).
- `features/`: `home` (Today + shell), `path`, `lesson` (exercise models, `ExerciseBuilder`, session notifier, views), `writing` (stroke board + matcher), `progress`, `words`, `settings`, `onboarding`, `about`, `ads`.

## German pack (added 2026-10-17)
- Pipeline: `scripts/build_content_de.py` (needs `wordfreq` in a venv: `python3 -m venv .venv && .venv/bin/pip install wordfreq`). Inputs from `scripts/fetch_sources.sh` into `data/raw/de/`: AI-assisted CEFR vocabulary (MIT), WiktionaryDE noun genders (CC BY-SA 4.0), Tatoeba. Authored: `content_src/de/core.txt` (function words and missing basics), `grammar_*.py` (60 points, helpers in `grammar_lib.py`), `pack.json`.
- Level policy: the AI CEFR tag picks the pool, wordfreq picks the most frequent words up to a quota (A1 600 … C1 1500; C2 is the rarer C1 remainder). Nouns carry the article in `text` (`der Hund`), plural in `note`.
- German-specific exercises: article choice (der/die/das), spelling by typing (accepts ae/oe/ue/ss), gender colours. Speech is judged on text by `TextTools` (`language_tools.dart`).
- The vocabulary and examples are AI-assisted: have a German speaker review before release. Known weak spots: C1/C2 tail words are rare, some Tatoeba matches are loose for irregular verbs.
- Gender rule: first-listed gender, example sentence, then `GENDER_OVERRIDE` in the script. Add to the override table when a common noun shows the wrong article.

## Content pipeline
`scripts/fetch_sources.sh` → `data/raw/` (gitignored) → `python3 scripts/build_content.py` → `assets/content/zh/` (committed). Authored files: `content_src/zh/pack.json`, `content_src/zh/grammar.json`. Output is deterministic; lesson ids are stored in users' progress, so never reorder words by hand. Sources and licences: `assets/licenses/`, About screen.

## Commands
- Tests: `flutter test` (69, both languages, includes whole lessons played through the UI at 339 dp / 1.3× text) · Analyze: `flutter analyze`
- Debug build: `nice -n 10 flutter build apk --debug`
- Release: see `docs/release.md`
- Icons: `python3 tool/make_icons.py`

## Machine notes
- **One heavy job at a time: never Gradle and the emulator together** (Homi's rule). Check `ps` for a running emulator before building.
- Phones: Samsung A12 (`192.168.100.111`) and Galaxy Tab S9 FE (`192.168.100.114`, tablet check) over wireless adb; a third unrelated phone (CPH2743) may show in `adb devices` via mDNS: **always pass `-s <serial>`**. Use `~/Android/Sdk/platform-tools/adb` (the `/usr/bin/adb` is too old). Port changes whenever wireless debugging is toggled; see the memory note `a12-wireless-adb`. The A12 runs 1.3× font and zoomed display (≈339 dp wide): design for that.
- Don't call `ref.read` inside `dispose()`; keep services in fields assigned in `initState`.
- `git`: commit before experiments; a bad scripted replace once wiped a file.
