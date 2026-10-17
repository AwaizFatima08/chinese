# Speak English (revision 3)

A separate tab for people who already speak English and want to sound clearer. Works offline, free, no accounts, no audio stored.

## What is in it
| Section | Content | Source |
|---|---|---|
| Sounds | 18 contrasts (ship/sheep, think/sink ...), 137 minimal pairs | own word lists, IPA from CMUdict |
| Word stress | 6 sets, 88 words incl. noun/verb pairs | own lists, stress from CMUdict |
| Vocabulary | 15 units, 300 advanced words, definitions + examples (own text) | own text, IPA from CMUdict |
| Sentences | 112 shadowing lines (rhythm, linking, intonation) | own text |
| Tongue twisters | 24 | own text |
| Conversations | 9 role-plays x 6 turns (coffee, hotel, directions, interview, doctor, restaurant call, party, returns, airport) | own text |

Build: `python3 scripts/build_speak_content.py` -> `assets/speak/*.json` (needs `data/raw/en/cmudict.dict` from `scripts/fetch_sources.sh`). Edit `content_src/speak/*.py`, never the JSON.

## How speech is judged
Device speech recognition (`speech_to_text`) gives text; `pronunciation.dart` aligns it to the target word by word (homophones and contractions normalised, single words need an exact hit, recogniser alternatives count as "close"). That measures clarity (are you understood), not accent as a native ear hears it. The UI says so.

Conversation turns: pick one of three model replies and read it (scored word by word), or switch to "Use your own words": the answer passes when it is 3+ words and contains a topic keyword. Free answers are not pronunciation-scored.

## Why no live AI conversation
Decided with the owner: free, no cloud AI, no per-use cost. Scripted role-plays give the structure of a conversation partner with zero running cost and nothing sent off the phone.

### Option kept for later: on-device small LLM
Measured on the test phones: Samsung A12 3.8 GB RAM (too small), Tab S9 FE 7.9 GB (feasible). Candidates via `flutter_gemma` / llama.cpp bindings: Gemma 3 1B / 270M, Qwen 2.5/3 0.5-0.6B, SmolLM 135M. Tiny models need >= 4 GB free RAM, 8 GB+ recommended; model files 300-800 MB would be an opt-in download (not bundled, AAB size). Quality of 0.5-1B models for free conversation is weak; check licences (Gemma terms, Qwen/SmolLM Apache-2.0) before shipping. Treat as an experiment on tablet-class devices only; the scripted mode must stay the default.

## Data and privacy
No new data leaves the device. Microphone is used for recognition by the Android recogniser (same as the language lessons). Progress is stored as language `en` and syncs with the optional backup like other languages. Credit: CMU Pronouncing Dictionary (About screen + licence file).

## Release
Revision 3 = version 1.2.0+3, after revision 2 is live. Needs Play listing text for the Speak tab; Data safety unchanged (microphone already declared by the recogniser use).

## Checks before release
- A native English speaker reviews sentences, role-plays and vocabulary examples.
- On a real phone: speak into each section, both US and UK accent.
- Tablet layout, 339 dp at 1.3x text (covered by tests for every kind of set).
