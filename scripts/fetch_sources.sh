#!/bin/bash
# fetch_sources.sh — downloads the open data the content pipeline needs into data/raw/.
# Sources (see docs/content-pipeline.md for licences):
#   complete-hsk-vocabulary (MIT)         — HSK word lists with pinyin + CC-CEDICT meanings
#   makemeahanzi graphics.txt (Arphic PL) — stroke paths + medians for stroke-order writing
#   makemeahanzi dictionary.txt (LGPL)    — per-character readings, build-time fallback only
#   Tatoeba cmn/eng exports (CC BY 2.0 FR) — example sentences
set -e
RAW="$(cd "$(dirname "$0")/.." && pwd)/data/raw"
mkdir -p "$RAW"
cd "$RAW"
curl -sS -L -o complete.min.json https://raw.githubusercontent.com/drkameleon/complete-hsk-vocabulary/main/complete.min.json
curl -sS -L -o mmah_COPYING https://raw.githubusercontent.com/skishore/makemeahanzi/master/COPYING
curl -sS -L -o mmah_APL_LICENSE https://raw.githubusercontent.com/skishore/makemeahanzi/master/APL/english/ARPHICPL.TXT
curl -sS -L -o mmah_dictionary.txt https://raw.githubusercontent.com/skishore/makemeahanzi/master/dictionary.txt
curl -sS -L -o mmah_graphics.txt https://raw.githubusercontent.com/skishore/makemeahanzi/master/graphics.txt
curl -sS -L -o cmn_sentences.tsv.bz2 https://downloads.tatoeba.org/exports/per_language/cmn/cmn_sentences.tsv.bz2
curl -sS -L -o cmn-eng_links.tsv.bz2 https://downloads.tatoeba.org/exports/per_language/cmn/cmn-eng_links.tsv.bz2
curl -sS -L -o eng_sentences.tsv.bz2 https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2
ls -la "$RAW"

# ---- German pack (data/raw/de) ----------------------------------------------
#   AI-assisted CEFR vocabulary (MIT), noun genders from WiktionaryDE (CC BY-SA 4.0),
#   Tatoeba German sentences and German-English links (CC BY 2.0 FR).
#   Build with: python3 -m venv .venv && .venv/bin/pip install wordfreq &&
#               .venv/bin/python scripts/build_content_de.py
mkdir -p "$RAW/de"
cd "$RAW/de"
for L in A1 A2 B1 B2 C1 C2; do
  curl -sSL -o "German_$L.csv" "https://raw.githubusercontent.com/AMevans12/Anki-Flash-Cards-Deutsch-ZhongWen/main/german/csv/German_$L.csv"
done
curl -sSL -o amevans_LICENSE.txt https://raw.githubusercontent.com/AMevans12/Anki-Flash-Cards-Deutsch-ZhongWen/main/LICENSE
curl -sSL -o german_nouns.csv https://raw.githubusercontent.com/gambolputty/german-nouns/main/german_nouns/nouns.csv
curl -sSL -o german_nouns_LICENSE.txt https://raw.githubusercontent.com/gambolputty/german-nouns/main/LICENSE
curl -sSL -o deu_sentences.tsv.bz2 https://downloads.tatoeba.org/exports/per_language/deu/deu_sentences.tsv.bz2
curl -sSL -o deu-eng_links.tsv.bz2 https://downloads.tatoeba.org/exports/per_language/deu/deu-eng_links.tsv.bz2
ls -la "$RAW/de"

# English speaking practice: CMU Pronouncing Dictionary (IPA and stress)
mkdir -p data/raw/en
[ -f data/raw/en/cmudict.dict ] || curl -sL -o data/raw/en/cmudict.dict https://raw.githubusercontent.com/cmusphinx/cmudict/master/cmudict.dict
[ -f data/raw/en/cmudict-LICENSE ] || curl -sL -o data/raw/en/cmudict-LICENSE https://raw.githubusercontent.com/cmusphinx/cmudict/master/LICENSE
