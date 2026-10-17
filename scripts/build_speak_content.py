#!/usr/bin/env python3
"""Builds assets/speak/*.json (spoken English practice) from content_src/speak/.

IPA and syllables come from the CMU Pronouncing Dictionary (American English),
fetched into data/raw/en/cmudict.dict by scripts/fetch_sources.sh.
Run: python3 scripts/build_speak_content.py
"""
import json, os, re, sys, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "content_src", "speak"))
from sounds import SOUNDS
from stress import STRESS
from sentences import SENTENCES
from twisters import TWISTERS
from vocab import VOCAB

OUT = os.path.join(ROOT, "assets", "speak")

VOWELS = {"AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "aʊ", "AY": "aɪ", "EH": "ɛ", "ER": "ɝ",
          "EY": "eɪ", "IH": "ɪ", "IY": "iː", "OW": "oʊ", "OY": "ɔɪ", "UH": "ʊ", "UW": "uː"}
CONS = {"B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "F": "f", "G": "ɡ", "HH": "h", "JH": "dʒ", "K": "k",
        "L": "l", "M": "m", "N": "n", "NG": "ŋ", "P": "p", "R": "r", "S": "s", "SH": "ʃ", "T": "t",
        "TH": "θ", "V": "v", "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ"}

# Legal English onsets (besides single consonants) used to split syllables.
ONSET2 = {("P","L"),("B","L"),("K","L"),("G","L"),("F","L"),("S","L"),("P","R"),("B","R"),("T","R"),("D","R"),
          ("K","R"),("G","R"),("F","R"),("TH","R"),("SH","R"),("T","W"),("D","W"),("K","W"),("G","W"),("S","W"),
          ("TH","W"),("S","P"),("S","T"),("S","K"),("S","M"),("S","N"),("S","F"),("P","Y"),("B","Y"),("T","Y"),
          ("D","Y"),("K","Y"),("G","Y"),("F","Y"),("V","Y"),("M","Y"),("N","Y"),("H","Y"),("L","Y"),("S","Y"),
          ("TH","Y"),("Z","Y")}
ONSET3 = {("S","P","L"),("S","P","R"),("S","T","R"),("S","K","R"),("S","K","W"),("S","K","L"),("S","P","Y"),
          ("S","T","Y"),("S","K","Y")}

def load_cmu():
    d = {}
    path = os.path.join(ROOT, "data", "raw", "en", "cmudict.dict")
    for line in open(path, encoding="latin-1"):
        if line.startswith(";;;") or not line.strip():
            continue
        head, *ph = line.split()
        m = re.match(r"^(.*?)(?:\((\d+)\))?$", head)
        d.setdefault(m.group(1).lower(), []).append(ph)
    return d

CMU = load_cmu()

UK_US = [("our", "or"), ("ise", "ize"), ("isation", "ization"), ("yse", "yze"), ("tre", "ter"), ("ence", "ense"), ("lled", "led")]
SPECIAL = {"sceptical": "skeptical", "enrol": "enroll", "grey": "gray", "programme": "program",
           "neighbourhood": "neighborhood", "wednesday": "wednesday", "sheik": "sheikh"}

def variants(word):
    w = word.lower()
    yield w
    if w in SPECIAL:
        yield SPECIAL[w]
    for a, b in UK_US:
        if w.endswith(a):
            yield w[: -len(a)] + b
        if a in w:
            yield w.replace(a, b)

def prons(word):
    for v in variants(word):
        if v in CMU:
            return CMU[v]
    return None

def split_syllables(phones):
    """ARPAbet phones -> list of syllables, each a list of phones."""
    idx = [i for i, p in enumerate(phones) if p[-1].isdigit()]
    if not idx:
        return [phones]
    cuts = [0]
    for a, b in zip(idx, idx[1:]):
        cluster = [re.sub(r"\d", "", p) for p in phones[a + 1:b]]
        k = 0  # number of consonants that go with the right-hand syllable
        for n in (3, 2, 1):
            if len(cluster) >= n:
                tail = tuple(cluster[-n:])
                ok = (n == 1 and tail[0] != "NG") or (n == 2 and tail in ONSET2) or (n == 3 and tail in ONSET3)
                if ok:
                    k = n
                    break
        cuts.append(b - k - (0 if k else 0) if False else (b - k))
    cuts.append(len(phones))
    # cuts[i] is where syllable i starts (for i>=1 it is the start of the onset)
    starts = [0] + [c for c in cuts[1:-1]]
    ends = starts[1:] + [len(phones)]
    return [phones[s:e] for s, e in zip(starts, ends)]

def syl_ipa(syl):
    out, mark = "", ""
    for p in syl:
        base = re.sub(r"\d", "", p)
        stress = p[-1] if p[-1].isdigit() else None
        if base in VOWELS:
            ipa = VOWELS[base]
            if base == "AH":
                ipa = "ʌ" if stress in ("1", "2") else "ə"
            if base == "ER":
                ipa = "ɝ" if stress in ("1", "2") else "ɚ"
            if stress == "1":
                mark = "ˈ"
            elif stress == "2":
                mark = "ˌ"
            out += ipa
        else:
            out += CONS[base]
    return mark + out

def word_info(word, want_stress=None):
    cands = prons(word)
    if cands is None:
        raise SystemExit(f"not in dictionary: {word}")
    chosen = None
    for ph in cands:
        syl = split_syllables(ph)
        primary = [i for i, s in enumerate(syl) if any(p.endswith("1") for p in s)]
        pos = (primary[0] + 1) if primary else None
        if want_stress is None or pos == want_stress:
            chosen = (ph, syl, pos)
            break
    if chosen is None:
        raise SystemExit(f"no variant of {word} with stress {want_stress}")
    ph, syl, pos = chosen
    ipa_syl = [syl_ipa(s) for s in syl]
    return {"syl": ipa_syl, "stress": pos, "ipa": "".join(ipa_syl)}

def main():
    os.makedirs(OUT, exist_ok=True)
    # sounds
    sounds = []
    for s in SOUNDS:
        pairs = []
        for a, b in s["pairs"]:
            pairs.append({"a": a, "b": b, "ia": word_info(a)["ipa"], "ib": word_info(b)["ipa"]})
        sounds.append({"id": s["id"], "title": s["title"], "symbols": s["symbols"], "tip": s["tip"],
                       "pairs": pairs, "phrases": s["phrases"]})
    # stress
    stress = []
    for s in STRESS:
        words = []
        for w in s["words"]:
            if isinstance(w, tuple):
                word, want, pos = w
                info = word_info(word, want)
                info.update({"w": word, "pos": pos})
            else:
                info = word_info(w)
                info["w"] = w
            if not info["stress"] or len(info["syl"]) < 2:
                raise SystemExit(f"stress set {s['id']}: {info['w']} needs two syllables and a stress")
            words.append(info)
        stress.append({"id": s["id"], "title": s["title"], "tip": s["tip"], "words": words})
    # vocabulary
    vocab, wid = [], 0
    for u in VOCAB:
        words = []
        for w, pos, defin, ex in u["words"]:
            wid += 1
            info = word_info(w)
            words.append({"id": wid, "w": w, "pos": pos, "def": defin, "ex": ex, "ipa": info["ipa"]})
        vocab.append({"id": u["id"], "title": u["title"], "words": words})
    sentences = [{"id": s["id"], "title": s["title"], "tip": s["tip"], "items": s["items"]} for s in SENTENCES]
    twisters = [dict(t) for t in TWISTERS]

    def dump(name, data):
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    dump("sounds.json", sounds)
    dump("stress.json", stress)
    dump("vocab.json", vocab)
    dump("sentences.json", sentences)
    dump("twisters.json", twisters)

    lic = os.path.join(ROOT, "assets", "licenses")
    os.makedirs(lic, exist_ok=True)
    shutil.copyfile(os.path.join(ROOT, "data", "raw", "en", "cmudict-LICENSE"), os.path.join(lic, "speak-cmudict.txt"))
    print(f"sounds {len(sounds)} sets, {sum(len(s['pairs']) for s in sounds)} pairs; stress {len(stress)} sets, "
          f"{sum(len(s['words']) for s in stress)} words; vocab {len(vocab)} units, {wid} words; "
          f"sentences {sum(len(s['items']) for s in sentences)}; twisters {len(twisters)}")

if __name__ == "__main__":
    main()
