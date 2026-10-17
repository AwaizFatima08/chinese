#!/usr/bin/env python3
"""build_content.py — builds the Chinese (zh) content pack for LingoDaily.

Reads data/raw/ (see scripts/fetch_sources.sh) and content_src/zh/ (authored
grammar + pack metadata) and writes assets/content/zh/:

  pack.json            language pack metadata + level list
  vocab.json           every HSK 1–6 word (HSK 2.0 lists): hanzi, pinyin, meanings
  sentences.json       example sentences (Tatoeba, CC BY 2.0 FR) with pinyin
  grammar.json         authored grammar points with pinyin derived from the vocabulary
  levels/hskN.json     the learning path: units → lessons (≤ 15 min each)
  strokes/hskN.json    stroke paths + medians for every character first met in level N

Deterministic: the same inputs always give the same output (lesson ids are
stored in the user's progress database, so never reorder words by hand).
"""
from __future__ import annotations

import bz2
import json
import math
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import packlib  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw")
SRC = os.path.join(ROOT, "content_src", "zh")
OUT = os.path.join(ROOT, "assets", "content", "zh")

# Words per vocabulary lesson, by level. Chosen so a lesson (warm-up review,
# teaching, listening, speaking, writing) fits in ~12–15 minutes.
WORDS_PER_LESSON = {1: 7, 2: 7, 3: 8, 4: 8, 5: 10, 6: 10}
VOCAB_LESSONS_PER_UNIT = 4
MAX_SENTENCES_PER_WORD = 3
# Max sentence length in characters (hanzi + punctuation) per level.
MAX_SENTENCE_LEN = {1: 14, 2: 16, 3: 18, 4: 22, 5: 26, 6: 30}

LEVEL_META = {
    1: ("HSK 1", "First words", "Greetings, numbers, family and daily basics. 150 words."),
    2: ("HSK 2", "Daily life", "Shopping, time, directions and simple conversation. 150 new words."),
    3: ("HSK 3", "Getting around", "Work, travel, feelings and opinions. 300 new words."),
    4: ("HSK 4", "Confident talk", "Discuss a wide range of topics fluently. 600 new words."),
    5: ("HSK 5", "Reading the world", "Newspapers, films and longer speeches. 1300 new words."),
    6: ("HSK 6", "Mastery", "Understand almost anything you hear or read. 2500 new words."),
}

CJK = re.compile(r"[一-鿿]")
PUNCT = set("，。！？、；：“”‘’（）《》…—·,.!?;:\"'()[] ")


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


# ---------------------------------------------------------------- vocabulary
BAD_MEANING = re.compile(
    r"^(surname |old variant|variant of|abbr\. for|used in |\(onom|\(old\)|see |\(archaic|\(literary)",
    re.I,
)


def clean_meaning(m: str) -> str:
    """Shortens a CC-CEDICT gloss for a flashcard."""
    m = m.strip()
    m = re.sub(r"\s*\(Note:.*$", "", m)
    m = m.replace("(bound form) ", "")
    if len(m) > 70:
        cut = m[:70]
        m = cut[: cut.rfind(";")] if ";" in cut else cut[: cut.rfind(" ")]
        m = m.rstrip(" ,;") + "…"
    return m


def form_meanings(fm: dict) -> list[str]:
    good, weak = [], []
    for m in fm.get("m", []):
        m = m.strip()
        if not m or "CL:" in m:
            continue
        (weak if BAD_MEANING.match(m) else good).append(clean_meaning(m))
    return good or weak


def best_form(forms: list[dict]) -> tuple[dict, list[str]]:
    """Picks the everyday reading: most real meanings, lowercase pinyin, earliest."""
    scored = []
    for idx, fm in enumerate(forms):
        meanings = form_meanings(fm)
        good = sum(0 if BAD_MEANING.match(m) else 1 for m in meanings)
        capital = 1 if fm["i"]["y"][:1].isupper() else 0
        scored.append((-good, capital, idx, fm, meanings))
    scored.sort(key=lambda t: t[:3])
    _, _, _, fm, meanings = scored[0]
    return fm, meanings


def load_vocab():
    with open(os.path.join(RAW, "complete.min.json"), encoding="utf-8") as f:
        raw = json.load(f)
    words = []
    all_simp_chars: set[str] = set()
    all_trad_chars: set[str] = set()
    full_dict: dict[str, dict] = {}  # every simplified word of any level → pinyin/meaning
    for e in raw:
        s = e["s"]
        forms = e.get("f") or []
        if not forms:
            continue
        f0, meanings = best_form(forms)
        all_simp_chars.update(CJK.findall(s))
        for fm in forms:
            all_trad_chars.update(CJK.findall(fm.get("t", "")))
        old_levels = sorted(int(l[1]) for l in e.get("l", []) if l.startswith("o"))
        new_levels = sorted(int(l[1]) for l in e.get("l", []) if l.startswith("n"))
        full_dict.setdefault(s, {
            "y": f0["i"]["y"], "n": f0["i"]["n"],
            "m": meanings,
            "lvl": old_levels[0] if old_levels else 9,
        })
        if not old_levels:
            continue
        meanings = list(dict.fromkeys(meanings))[:4]
        if not meanings:
            continue
        words.append({
            "s": s,
            "t": f0.get("t", s),
            "y": f0["i"]["y"],          # pinyin with tone marks
            "n": f0["i"]["n"],          # pinyin with tone numbers
            "m": meanings,
            "pos": e.get("p", [])[:3],
            "lvl": old_levels[0],
            "hsk3": new_levels[0] if new_levels else None,
            "q": e.get("q") if isinstance(e.get("q"), int) else 10**9,
            "cl": [c.get("s", "") for c in f0.get("c", []) if isinstance(c, dict)][:2],
        })
    # Stable order: level, then frequency rank, then the word itself.
    words.sort(key=lambda w: (w["lvl"], w["q"], w["s"]))
    # Deduplicate by simplified form (keep the lowest level).
    seen = set()
    uniq = []
    for w in words:
        if w["s"] in seen:
            continue
        seen.add(w["s"])
        uniq.append(w)
    for i, w in enumerate(uniq):
        w["id"] = i + 1
    trad_only = all_trad_chars - all_simp_chars
    return uniq, full_dict, trad_only


# ------------------------------------------------------------ segmentation
class Segmenter:
    """Forward maximum-match tokeniser over the full HSK dictionary."""

    def __init__(self, full_dict: dict[str, dict], char_pinyin: dict[str, str]):
        self.words = set(full_dict)
        self.max_len = max(len(w) for w in self.words)
        self.full_dict = full_dict
        self.char_pinyin = char_pinyin

    def tokens(self, text: str) -> list[str]:
        out = []
        i = 0
        while i < len(text):
            ch = text[i]
            if not CJK.match(ch):
                j = i + 1
                if ch.isalnum():
                    while j < len(text) and text[j].isalnum() and not CJK.match(text[j]):
                        j += 1
                out.append(text[i:j])
                i = j
                continue
            best = ch
            for n in range(min(self.max_len, len(text) - i), 1, -1):
                cand = text[i:i + n]
                if cand in self.words:
                    best = cand
                    break
            out.append(best)
            i += len(best)
        return out

    def pinyin(self, tok: str) -> str:
        if tok in self.full_dict:
            return self.full_dict[tok]["y"]
        if len(tok) == 1 and tok in self.char_pinyin:
            return self.char_pinyin[tok]
        if CJK.match(tok):
            return "".join(self.char_pinyin.get(c, c) for c in tok)
        return tok

    def sentence_pinyin(self, text: str) -> str:
        parts = []
        for tok in self.tokens(text):
            if tok in PUNCT or not CJK.search(tok):
                parts.append(tok)
            else:
                parts.append(self.pinyin(tok))
        # Tidy spaces around punctuation.
        s = " ".join(parts)
        s = re.sub(r"\s+([，。！？、；：”’）》])", r"\1", s)
        s = re.sub(r"([“‘（《])\s+", r"\1", s)
        return re.sub(r"\s{2,}", " ", s).strip()


def load_char_pinyin() -> dict[str, str]:
    """Build-time fallback readings for characters outside the HSK vocabulary."""
    out = {}
    with open(os.path.join(RAW, "mmah_dictionary.txt"), encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            if e.get("pinyin"):
                out[e["character"]] = e["pinyin"][0]
    return out


# --------------------------------------------------------------- sentences
def load_tatoeba(trad_only: set[str]):
    def read(name):
        with bz2.open(os.path.join(RAW, name), "rt", encoding="utf-8") as f:
            for line in f:
                yield line.rstrip("\n").split("\t")

    cmn = {}
    for row in read("cmn_sentences.tsv.bz2"):
        if len(row) < 3:
            continue
        sid, text = int(row[0]), row[2].strip()
        if any(c in trad_only for c in text):
            continue
        if not CJK.search(text):
            continue
        cmn[sid] = text
    links = defaultdict(list)
    for row in read("cmn-eng_links.tsv.bz2"):
        if len(row) < 2:
            continue
        a, b = int(row[0]), int(row[1])
        if a in cmn:
            links[a].append(b)
    needed = {b for bs in links.values() for b in bs}
    eng = {}
    for row in read("eng_sentences.tsv.bz2"):
        if len(row) < 3:
            continue
        sid = int(row[0])
        if sid in needed:
            eng[sid] = row[2].strip()
    pairs = []
    for a, bs in links.items():
        trans = [eng[b] for b in bs if b in eng]
        if not trans:
            continue
        trans.sort(key=len)
        pairs.append((a, cmn[a], trans[0]))
    pairs.sort()
    log(f"tatoeba: {len(cmn)} simplified cmn sentences, {len(pairs)} with English")
    return pairs


def pick_sentences(words, pairs, seg: Segmenter):
    by_word = {w["s"]: w for w in words}
    level_of = {w["s"]: w["lvl"] for w in words}
    candidates: dict[str, list] = defaultdict(list)
    sentence_rows = {}
    for sid, zh, en in pairs:
        if len(zh) > 30 or len(zh) < 3 or "\n" in zh:
            continue
        toks = seg.tokens(zh)
        word_toks = [t for t in toks if CJK.search(t)]
        if not word_toks:
            continue
        lvls = [level_of.get(t, 9) for t in word_toks]
        unknown = sum(1 for l in lvls if l == 9)
        known_max = max([l for l in lvls if l != 9] or [1])
        for t in set(word_toks):
            if t not in by_word:
                continue
            w = by_word[t]
            L = w["lvl"]
            if len(zh) > MAX_SENTENCE_LEN[L]:
                continue
            # Everything in the sentence should be at or below the word's level;
            # from HSK 3 on, allow one harder/unknown token.
            harder = sum(1 for l in lvls if l != 9 and l > L)
            if harder + unknown > 1:
                continue
            score = (harder + unknown, len(zh), sid)
            candidates[t].append((score, sid))
        sentence_rows[sid] = (zh, en, toks, known_max if unknown == 0 else min(6, known_max + 1))
    chosen = {}
    used: dict[int, dict] = {}
    for w in words:
        cands = sorted(candidates.get(w["s"], []))[:MAX_SENTENCES_PER_WORD]
        ids = []
        for _, sid in cands:
            if sid not in used:
                zh, en, toks, lvl = sentence_rows[sid]
                used[sid] = {
                    "id": sid, "t": zh, "en": en,
                    "r": seg.sentence_pinyin(zh), "lvl": lvl,
                    "w": [by_word[t]["id"] for t in toks if t in by_word],
                }
            ids.append(sid)
        chosen[w["id"]] = ids
    coverage = {L: 0 for L in range(1, 7)}
    totals = {L: 0 for L in range(1, 7)}
    for w in words:
        totals[w["lvl"]] += 1
        if chosen[w["id"]]:
            coverage[w["lvl"]] += 1
    for L in range(1, 7):
        log(f"sentences: HSK{L} words with examples {coverage[L]}/{totals[L]}")
    rows = sorted(used.values(), key=lambda r: r["id"])
    return chosen, rows


# ----------------------------------------------------------------- grammar
def load_grammar(seg: Segmenter):
    path = os.path.join(SRC, "grammar.json")
    if not os.path.exists(path):
        log("grammar: content_src/zh/grammar.json missing — no grammar lessons")
        return []
    with open(path, encoding="utf-8") as f:
        points = json.load(f)
    for p in points:
        for ex in p.get("examples", []):
            if "r" not in ex:
                ex["r"] = seg.sentence_pinyin(ex["t"])
        for q in p.get("quiz", []):
            if q.get("type") == "order":
                q.setdefault("r", seg.sentence_pinyin(q["answer"]))
                q["tokens"] = [t for t in seg.tokens(q["answer"]) if t not in PUNCT]
    log(f"grammar: {len(points)} points")
    return points


# ------------------------------------------------------------- learning path
def build_levels(words, chosen, grammar):
    return packlib.build_levels(
        "zh", [f"hsk{n}" for n in range(1, 7)], LEVEL_META, words, chosen, grammar,
        WORDS_PER_LESSON, {1: 10, 2: 10, 3: 11, 4: 11, 5: 11, 6: 11},
    )


# ------------------------------------------------------------------ strokes
def build_strokes(words):
    first_level: dict[str, int] = {}
    for w in words:  # words are sorted by level
        for c in CJK.findall(w["s"]):
            first_level.setdefault(c, w["lvl"])
    out = {L: {} for L in range(1, 7)}
    with open(os.path.join(RAW, "mmah_graphics.txt"), encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            c = e["character"]
            if c in first_level:
                out[first_level[c]][c] = {
                    "s": e["strokes"],
                    "m": [[[int(x), int(y)] for x, y in med] for med in e["medians"]],
                }
    missing = [c for c in first_level if c not in out[first_level[c]]]
    log(f"strokes: {len(first_level)} characters, missing {len(missing)}: {''.join(missing[:20])}")
    return out


# --------------------------------------------------------------------- main
def dump(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))
    log(f"wrote {os.path.relpath(path, ROOT)} ({os.path.getsize(path) // 1024} KB)")


def main():
    words, full_dict, trad_only = load_vocab()
    log(f"vocab: {len(words)} HSK 2.0 words; {len(trad_only)} traditional-only characters excluded")
    seg = Segmenter(full_dict, load_char_pinyin())
    pairs = load_tatoeba(trad_only)
    chosen, sentence_rows = pick_sentences(words, pairs, seg)
    grammar = load_grammar(seg)
    levels = build_levels(words, chosen, grammar)
    strokes = build_strokes(words)

    for w in words:
        w["ex"] = chosen[w["id"]]
        w.pop("q", None)
    dump(os.path.join(OUT, "vocab.json"), words)
    dump(os.path.join(OUT, "sentences.json"), sentence_rows)
    dump(os.path.join(OUT, "grammar.json"), grammar)
    for lv in levels:
        dump(os.path.join(OUT, "levels", f"{lv['id']}.json"), lv)
    for L, table in strokes.items():
        dump(os.path.join(OUT, "strokes", f"hsk{L}.json"), table)
    # character → level file that holds its strokes
    index = {c: L for L, table in strokes.items() for c in table}
    dump(os.path.join(OUT, "strokes", "index.json"), index)

    with open(os.path.join(SRC, "pack.json"), encoding="utf-8") as f:
        pack = json.load(f)
    pack["levels"] = [{k: v for k, v in lv.items() if k != "units"} for lv in levels]
    pack["wordCount"] = len(words)
    pack["sentenceCount"] = len(sentence_rows)
    pack["grammarCount"] = len(grammar)
    dump(os.path.join(OUT, "pack.json"), pack)


if __name__ == "__main__":
    main()
