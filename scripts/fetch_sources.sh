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
