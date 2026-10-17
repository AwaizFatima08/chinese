# Lingo15

Learn **Chinese (HSK 1–6)** and **German (CEFR A1–C2)** on Android in **15 minutes a day** by listening, speaking, reading and writing. Built to host more languages.

## What it does
- **Short daily plan.** Each lesson is a chain of 5–60 second steps and takes 4–11 minutes. The Today screen shows one next lesson plus a spaced-repetition warm-up. At 15 minutes studied the app suggests stopping.
- **Verbal teaching.** A teacher voice (device text-to-speech) says each word, its meaning and an example; learners repeat and are checked by speech recognition, judged by sound and tone.
- **Written language.** Stroke-order demonstrations and finger tracing for every character in HSK 1–6 (2,600+ characters).
- **Full paths.** Chinese: 4,991 HSK 2.0 words, 62 grammar points, 700+ lessons. German: about 5,850 words with articles and plurals, 60 grammar points, 930 lessons. Unit checkpoints and spaced-repetition review for both.
- **German extras.** der/die/das colour hints, article questions and spelling practice instead of stroke writing.
- **Ads.** AdMob banner on the main tabs, an interstitial only between lessons (rarely), and a rewarded video to save a broken streak.
- **More languages later.** Content lives in language packs: see `docs/add-a-language.md`.

## Run it
```bash
flutter pub get
flutter run            # debug build with Google test ads
flutter test           # 69 tests, both languages, lessons played through the UI
```
Rebuild content: `bash scripts/fetch_sources.sh && python3 scripts/build_content.py`.

## Docs
`CLAUDE.md` (project guide) · `docs/add-a-language.md` · `docs/ads.md` · `docs/release.md`

## Data credits
Word lists: complete-hsk-vocabulary (MIT). Meanings: CC-CEDICT (CC BY-SA 4.0). Sentences: Tatoeba (CC BY 2.0 FR). Stroke data: Make Me a Hanzi (Arphic Public License / LGPL). Shown in the app's About screen; texts in `assets/licenses/`.
