# Adding a language

A language is a **content pack** plus one registry line. No Dart changes are needed unless the language needs a new kind of exercise.

## 1. Pack folder `assets/content/<id>/`

| File | Contents |
|---|---|
| `pack.json` | `id`, `name`, `nativeName`, `flag`, `script`, `romanizationLabel`, `ttsLocale` (e.g. `ja-JP`), `sttLocale` (e.g. `ja_JP`), `hasTones`, `hasStrokeWriting`, `levelLabel`, `levels[]`, `attribution[]` |
| `vocab.json` | list of words: `id`, `s` (text), `t` (alt script), `y` (romanization shown), `n` (numeric/plain romanization), `m` (meanings), `pos`, `lvl`, `ex` (sentence ids) |
| `sentences.json` | `id`, `zh` (text), `en`, `py` (romanization), `lvl`, `w` (word ids) |
| `grammar.json` | grammar points with `examples` and `quiz` (see `content_src/zh/grammar.json`) |
| `levels/<levelId>.json` | the path: units → lessons (`vocab`, `grammar`, `checkpoint`) |
| `strokes/` | optional; `index.json` (char → file) and one file per level |

Field names are historical (`zh`, `py`); they are the schema for every language.

## 2. Register it
Add the id to `available` in `assets/content/languages.json` (move it out of `comingSoon`), and list the folder in `pubspec.yaml` assets.

## 3. Build script
Copy `scripts/build_content.py` to `scripts/build_content_<id>.py` and replace the loaders. Keep it deterministic. Check licences of every source; add them to `attribution` and `assets/licenses/`.

## 4. Check
- `flutter test test/exercise_builder_test.dart` style test for the new pack: every lesson must build and stay under 15 minutes.
- Install the TTS voice for the language on the test phone; speech recognition needs the language too.
- Languages without tones: set `hasTones: false` (hides tone colours and tone drills). Without hand-writing support set `hasStrokeWriting: false`.

## Not yet generalised
- `PinyinLookup` (speech matching by sound) is Chinese-specific; other languages fall back to exact text comparison until a lookup is written.
- The UI string table is English only; add `app_<locale>.arb` for UI translations (Urdu would need RTL checks).
