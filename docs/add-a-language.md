# Adding a language

Worked example: German (`scripts/build_content_de.py`, `content_src/de/`). Chinese is the other reference (`scripts/build_content.py`). Both use `scripts/packlib.py` to build levels, units and lessons.

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

Word keys: `s` text, `l` lemma, `g` article, `x` note (shown under the word), `y`/`n` romanization, `m` meanings, `pos`, `lvl`, `ex` sentence ids. Sentence keys: `t` text, `en`, `r` romanization, `lvl`, `w`. The same keys serve every language.

## 2. Register it
Add the id to `available` in `assets/content/languages.json` (move it out of `comingSoon`), and list the folder in `pubspec.yaml` assets.

## 3. Build script
Copy `scripts/build_content.py` to `scripts/build_content_<id>.py` and replace the loaders. Keep it deterministic. Check licences of every source; add them to `attribution` and `assets/licenses/`.

## 4. Check
- `flutter test test/exercise_builder_test.dart` style test for the new pack: every lesson must build and stay under 15 minutes.
- Install the TTS voice for the language on the test phone; speech recognition needs the language too.
- Pack capability flags: `hasGender` (article questions, `colorCoding: genders`), `typingPractice` (spelling instead of strokes), `hasRomanization`, `voiceTestPhrase`, `licenseFiles`. Languages without tones: set `hasTones: false` (hides tone colours and tone drills). Without hand-writing support set `hasStrokeWriting: false`.

## Not yet generalised
- Speech matching lives behind `LanguageTools` (`language_tools.dart`): `ChineseTools` judges by pinyin, `TextTools` by normalised text with article and typo tolerance. Add a class there for a language that needs different rules (for example Japanese kana).
- The UI string table is English only; add `app_<locale>.arb` for UI translations (Urdu would need RTL checks).
