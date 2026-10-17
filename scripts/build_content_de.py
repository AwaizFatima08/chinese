#!/usr/bin/env python3
"""build_content_de.py — builds the German (de) content pack for LingoDaily.

Inputs (data/raw/de, see scripts/fetch_sources.sh):
  German_A1..C2.csv     AI-assisted vocabulary with CEFR tags, meanings, examples (MIT, AMevans12)
  german_nouns.csv      noun genders and case forms from German Wiktionary (CC BY-SA 4.0, gambolputty)
  deu_sentences / deu-eng_links / eng_sentences   Tatoeba (CC BY 2.0 FR)
Authored: content_src/de/core.txt (function words), grammar.json, pack.json.

Output: assets/content/de/ (pack, vocab, sentences, grammar, levels/*.json).

Level policy: the AI CEFR tag decides which pool a word comes from; within a pool
the most frequent words (wordfreq) are taken first, up to a per-level quota.
C2 is the less frequent remainder of the C1 pool plus the few C2-tagged words.
Deterministic: same inputs, same output (lesson ids are stored in progress).

Needs: python3 with `wordfreq` (pip install wordfreq in a venv).
"""
from __future__ import annotations

import bz2
import csv
import json
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import packlib  # noqa: E402
from packlib import log  # noqa: E402

try:
    from wordfreq import zipf_frequency
except ImportError:  # pragma: no cover
    sys.exit("pip install wordfreq (use a virtualenv)")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw", "de")
SRC = os.path.join(ROOT, "content_src", "de")
OUT = os.path.join(ROOT, "assets", "content", "de")

LEVELS = ["a1", "a2", "b1", "b2", "c1", "c2"]
QUOTA = {1: 600, 2: 700, 3: 900, 4: 1200, 5: 1500, 6: 1200}
WORDS_PER_LESSON = {1: 7, 2: 8, 3: 8, 4: 9, 5: 9, 6: 9}
VOCAB_MINUTES = {1: 10, 2: 10, 3: 10, 4: 11, 5: 11, 6: 11}
LEVEL_META = {
    1: ("A1", "First steps", "Greetings, numbers, family, food and everyday basics."),
    2: ("A2", "Everyday life", "Shopping, travel, work and simple conversation."),
    3: ("B1", "On your own", "Cope with most situations while travelling or at work."),
    4: ("B2", "Fluent talk", "Discuss many topics with spontaneity and detail."),
    5: ("C1", "Skilled use", "Express yourself fluently in demanding contexts."),
    6: ("C2", "Mastery", "Rarer and specialised words for near-native command."),
}
AM_LEVEL = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5, "C2": 6}
ARTICLE = {"m": "der", "f": "die", "n": "das"}
# Words that are not nouns, or that should not be taught as vocabulary.
# Function words a sentence may start with; lowered in word-order tiles so a
# capital letter does not give the first tile away.
CLOSED_CLASS = {"der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer",
                "ich", "du", "er", "es", "wir", "ihr", "man", "mein", "meine", "meinen", "meinem",
                "dein", "deine", "unser", "unsere", "kein", "keine", "keinen", "wo", "wer", "was",
                "wie", "wann", "warum", "welche", "welcher", "woher", "wohin", "heute", "morgen",
                "gestern", "jetzt", "hier", "dort", "dann", "da", "in", "im", "am", "um", "mit",
                "bei", "nach", "vor", "auf", "an", "aus", "von", "zu", "zum", "zur", "für",
                "wenn", "weil", "dass", "ob", "als", "obwohl", "bevor", "nachdem", "während",
                "sobald", "nicht", "nie", "selten", "kaum", "alles", "nichts", "viele", "manche"}
NOT_NOUNS = {"Sie", "Er", "Es", "Ich", "Du", "Wir", "Ihr", "Ja", "Nein", "Antisemit",
             "Antisemitismus", "Rassist", "Nazi", "Hitler"}
MONTHS_DAYS = {"Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
               "September", "Oktober", "November", "Dezember", "Montag", "Dienstag",
               "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag", "Frühling",
               "Sommer", "Herbst", "Winter"}
NO_PLURAL = MONTHS_DAYS
# Translations containing these are left out (offensive or unsuitable for a general course).
BLOCK = re.compile(
    r"\b(vulgar|offensive|slur|derogatory|obscene|sexual|fornication|prostitut|rape|"
    r"nazi|swastika|genital|penis|vagina|porn|erotic|lewd|whore|bastard)\b", re.I)
# Crude or sensitive German words: never taught, and sentences containing them are skipped.
DE_BLOCK = re.compile(
    r"(fick|scheiß|scheiss|hure|nutte|schwanz|arsch|wichs|porno|sex|titte|pimmel|vögel|schlampe|"
    r"nazi|hitler|neger|kanak|terror|selbstmord|vergewalt|massaker|holocaust|geschlechtsverkehr|"
    r"erotik|bordell|prostitu|missbrauch|folter|mord)", re.I)
NAMES = {"tom", "mary", "maria", "john", "tom's", "mary's", "boston", "marika", "sami",
         "layla", "tatoeba", "muiriel", "alice", "bob", "fadil", "tom,"}


# ------------------------------------------------------------------ helpers
def zipf(word: str) -> float:
    z = zipf_frequency(word, "de")
    if z == 0 and " " in word:
        z = min((zipf_frequency(p, "de") for p in word.split()), default=0)
    return z or 1.0


def norm_pos(raw: str) -> str | None:
    """Maps the source's free-text part of speech to one of our few categories."""
    p = raw.lower().strip()
    if "noun" in p:
        return "noun"
    if re.search(r"\badj|adjektiv", p):
        return "adjective"
    if re.search(r"\badv|adverb", p):
        return "adverb"
    if re.search(r"\bverb\b", p) and "participle" not in p:
        return "verb"
    if p in ("numeral", "number"):
        return "number"
    if p in ("preposition", "conjunction", "determiner", "pronoun", "phrase"):
        return p
    return None


def split_meanings(text: str) -> list[str]:
    out = []
    for m in re.split(r"\s*;\s*", text.strip()):
        m = m.strip()
        if m and m not in out:
            out.append(m)
    return out[:4]


# --------------------------------------------------------------------- nouns
PRIMARY: dict[str, str] = {}  # lemma -> first-listed gender in the noun dataset

# Standard gender for common nouns the dataset lists with regional variants.
GENDER_OVERRIDE = {
    "Meter": "m", "Kilometer": "m", "Zentimeter": "m", "Millimeter": "m", "Liter": "m",
    "Monat": "m", "Euro": "m", "Tee": "m", "Kaffee": "m", "Radio": "n", "Foto": "n",
    "Ort": "m", "Mund": "m", "Joghurt": "m", "Quark": "m", "Butter": "f", "Cola": "f",
    "Teil": "m", "Prozent": "n", "Bonbon": "n", "Gummi": "m", "Spaghetti": "f",
    "Virus": "n", "Kiwi": "f", "Sakko": "n", "Dativ": "m", "Wiki": "n",
}


def load_nouns() -> dict[str, dict[str, dict]]:
    """lemma -> {gender letter -> info}. Homonyms such as der/das Service keep both."""
    table: dict[str, dict[str, dict]] = {}
    with open(os.path.join(RAW, "german_nouns.csv"), encoding="utf-8") as f:
        rd = csv.DictReader(f)
        case_cols = [c for c in rd.fieldnames
                     if re.match(r"(nominativ|genitiv|dativ|akkusativ) (singular|plural)( \d)?$", c)]
        for r in rd:
            lemma = r["lemma"]
            genders = {(r.get(c) or "").strip() for c in ("genus", "genus 1", "genus 2", "genus 3", "genus 4")}
            genders = {g for g in genders if g in ARTICLE}
            if not genders:
                continue
            primary = (r.get("genus") or r.get("genus 1") or "").strip()
            if primary in ARTICLE and lemma not in PRIMARY:
                PRIMARY[lemma] = primary
            forms = {r[c] for c in case_cols if r[c] and r[c] not in ("—", "-")}
            plural = (r.get("nominativ plural") or r.get("nominativ plural 1") or "").strip()
            plural = plural if plural not in ("—", "-") else ""
            for g in genders:
                slot = table.setdefault(lemma, {})
                if g not in slot:
                    slot[g] = {"g": g, "plural": plural, "forms": set(forms)}
                else:
                    slot[g]["forms"] |= forms
    log(f"nouns: {len(table)} with gender; {sum(1 for v in table.values() if len(v) > 1)} ambiguous")
    return table


# Nouns that only exist in the plural: always "die", no singular.
PLURAL_ONLY = {"Eltern", "Leute", "Ferien", "Geschwister", "Kosten", "Lebensmittel", "Möbel"}


def pick_noun(nouns: dict, lemma: str, example: str) -> dict | None:
    """The noun's info. Two-gender nouns: override, then the example sentence, then
    the first-listed (standard) gender."""
    if lemma in PLURAL_ONLY:
        return {"g": "f", "plural": "", "forms": {lemma, lemma + "n"}, "plural_only": True}
    slot = nouns.get(lemma)
    if not slot:
        return None
    if len(slot) == 1:
        return next(iter(slot.values()))
    forced = GENDER_OVERRIDE.get(lemma)
    if forced in slot:
        return slot[forced]
    toks = tokens(example)
    for i, t in enumerate(toks):
        if t == lemma and i > 0:
            prev = toks[i - 1].lower()
            gender = {"der": "m", "das": "n"}.get(prev)
            if prev == "die" and "f" in slot:
                gender = "f"
            if gender in slot:
                return slot[gender]
    primary = PRIMARY.get(lemma)
    return slot.get(primary) if primary in slot else None


# --------------------------------------------------------------------- verbs
SEPARABLE = ["ab", "an", "auf", "aus", "bei", "ein", "fest", "fort", "her", "hin", "los", "mit",
             "nach", "statt", "teil", "vor", "weg", "weiter", "zu", "zurück", "zusammen", "heraus",
             "hinaus", "herein", "hinein", "heim", "um", "frei", "wieder", "dar", "vorbei", "zurecht"]
IRREGULAR = {
    "sein": "bin bist ist sind seid war warst waren wart gewesen sei wäre wären",
    "haben": "habe hast hat habt hatte hattest hatten hattet gehabt hätte hätten",
    "werden": "werde wirst wird werdet wurde wurdest wurden wurdet geworden worden würde würden",
    "können": "kann kannst können könnt konnte konntest konnten gekonnt könnte könnten",
    "müssen": "muss musst müssen müsst musste musstest mussten gemusst müsste müssten",
    "wollen": "will willst wollen wollt wollte wolltest wollten gewollt",
    "sollen": "soll sollst sollen sollt sollte solltest sollten gesollt",
    "dürfen": "darf darfst dürfen dürft durfte durftest durften gedurft dürfte dürften",
    "mögen": "mag magst mögen mögt mochte mochtest mochten gemocht möchte möchtest möchten möchtet",
    "wissen": "weiß weißt wissen wisst wusste wusstest wussten gewusst wüsste",
    "gehen": "gehe gehst geht gehen ging gingst gingen gingt gegangen",
    "kommen": "komme kommst kommt kommen kam kamst kamen kamt gekommen käme",
    "stehen": "stehe stehst steht stehen stand standen gestanden",
    "sehen": "sehe siehst sieht sehen seht sah sahen gesehen",
    "geben": "gebe gibst gibt geben gebt gab gaben gegeben",
    "nehmen": "nehme nimmst nimmt nehmen nehmt nahm nahmen genommen",
    "essen": "esse isst essen esst aß aßen gegessen",
    "trinken": "trinke trinkst trinkt trinken trank tranken getrunken",
    "sprechen": "spreche sprichst spricht sprechen sprecht sprach sprachen gesprochen",
    "lesen": "lese liest lesen lest las lasen gelesen",
    "schreiben": "schreibe schreibst schreibt schreiben schrieb schrieben geschrieben",
    "fahren": "fahre fährst fährt fahren fahrt fuhr fuhren gefahren",
    "laufen": "laufe läufst läuft laufen lauft lief liefen gelaufen",
    "schlafen": "schlafe schläfst schläft schlafen schlaft schlief schliefen geschlafen",
    "helfen": "helfe hilfst hilft helfen helft half halfen geholfen",
    "finden": "finde findest findet finden fand fanden gefunden",
    "bleiben": "bleibe bleibst bleibt bleiben blieb blieben geblieben",
    "bringen": "bringe bringst bringt bringen brachte brachten gebracht",
    "denken": "denke denkst denkt denken dachte dachten gedacht",
    "kennen": "kenne kennst kennt kennen kannte kannten gekannt",
    "nennen": "nenne nennst nennt nennen nannte nannten genannt",
    "liegen": "liege liegst liegt liegen lag lagen gelegen",
    "sitzen": "sitze sitzt sitzen saß saßen gesessen",
    "tun": "tue tust tut tun tat taten getan",
    "lassen": "lasse lässt lassen lasst ließ ließen gelassen",
    "halten": "halte hältst hält halten haltet hielt hielten gehalten",
    "tragen": "trage trägst trägt tragen tragt trug trugen getragen",
    "treffen": "treffe triffst trifft treffen trefft traf trafen getroffen",
    "fallen": "falle fällst fällt fallen fallt fiel fielen gefallen",
    "rufen": "rufe rufst ruft rufen rief riefen gerufen",
    "ziehen": "ziehe ziehst zieht ziehen zog zogen gezogen",
    "beginnen": "beginne beginnst beginnt beginnen begann begannen begonnen",
    "gewinnen": "gewinne gewinnst gewinnt gewinnen gewann gewannen gewonnen",
    "verlieren": "verliere verlierst verliert verlieren verlor verloren",
    "verstehen": "verstehe verstehst versteht verstehen verstand verstanden",
    "vergessen": "vergesse vergisst vergessen vergaß vergaßen",
    "bekommen": "bekomme bekommst bekommt bekommen bekam bekamen",
    "singen": "singe singst singt singen sang sangen gesungen",
    "schwimmen": "schwimme schwimmst schwimmt schwimmen schwamm schwammen geschwommen",
    "schneiden": "schneide schneidest schneidet schneiden schnitt schnitten geschnitten",
    "schlagen": "schlage schlägst schlägt schlagen schlug schlugen geschlagen",
    "steigen": "steige steigst steigt steigen stieg stiegen gestiegen",
    "scheinen": "scheine scheinst scheint scheinen schien schienen geschienen",
    "waschen": "wasche wäschst wäscht waschen wascht wusch wuschen gewaschen",
    "werfen": "werfe wirfst wirft werfen werft warf warfen geworfen",
    "brechen": "breche brichst bricht brechen brecht brach brachen gebrochen",
    "sterben": "sterbe stirbst stirbt sterben starb starben gestorben",
    "heißen": "heiße heißt heißen hieß hießen geheißen",
    "gelten": "gelte giltst gilt gelten galt galten gegolten",
    "wachsen": "wachse wächst wachsen wachst wuchs wuchsen gewachsen",
    "bitten": "bitte bittest bittet bitten bat baten gebeten",
    "leiden": "leide leidest leidet leiden litt litten gelitten",
    "meiden": "meide meidest meidet meiden mied mieden gemieden",
    "gießen": "gieße gießt gießen goss gossen gegossen",
    "fliegen": "fliege fliegst fliegt fliegen flog flogen geflogen",
    "fließen": "fließe fließt fließen floss flossen geflossen",
    "frieren": "friere frierst friert frieren fror froren gefroren",
    "hängen": "hänge hängst hängt hängen hing hingen gehangen",
    "klingen": "klinge klingst klingt klingen klang klangen geklungen",
    "lügen": "lüge lügst lügt lügen log logen gelogen",
    "riechen": "rieche riechst riecht riechen roch rochen gerochen",
    "schließen": "schließe schließt schließen schloss schlossen geschlossen",
    "springen": "springe springst springt springen sprang sprangen gesprungen",
    "streiten": "streite streitest streitet streiten stritt stritten gestritten",
    "treiben": "treibe treibst treibt treiben trieb trieben getrieben",
    "wählen": "wähle wählst wählt wählen wählte wählten gewählt",
    "backen": "backe bäckst bäckt backen buk backte gebacken",
    "binden": "binde bindest bindet binden band banden gebunden",
    "bieten": "biete bietest bietet bieten bot boten geboten",
    "empfehlen": "empfehle empfiehlst empfiehlt empfehlen empfahl empfahlen",
    "entscheiden": "entscheide entscheidest entscheidet entscheiden entschied entschieden",
    "erfinden": "erfinde erfindest erfindet erfinden erfand erfanden erfunden",
    "gefallen": "gefalle gefällst gefällt gefallen gefiel gefielen",
    "gelingen": "gelinge gelingt gelingen gelang gelangen gelungen",
    "genießen": "genieße genießt genießen genoss genossen",
    "geschehen": "geschieht geschehen geschah geschahen",
    "graben": "grabe gräbst gräbt graben grub gruben gegraben",
    "greifen": "greife greifst greift greifen griff griffen gegriffen",
    "messen": "messe misst messen messt maß maßen gemessen",
    "raten": "rate rätst rät raten ratet riet rieten geraten",
    "reiten": "reite reitest reitet reiten ritt ritten geritten",
    "rennen": "renne rennst rennt rennen rannte rannten gerannt",
    "senden": "sende sendest sendet senden sandte sandten gesandt",
    "setzen": "setze setzt setzen setzte setzten gesetzt",
    "stehlen": "stehle stiehlst stiehlt stehlen stahl stahlen gestohlen",
    "vermeiden": "vermeide vermeidest vermeidet vermeiden vermied vermieden",
    "verbieten": "verbiete verbietest verbietet verbieten verbot verboten",
    "verbinden": "verbinde verbindest verbindet verbinden verband verbanden verbunden",
    "verschwinden": "verschwinde verschwindest verschwindet verschwinden verschwand verschwanden verschwunden",
}


def verb_forms(inf: str) -> set[str]:
    """Surface forms of a verb: a table for irregular verbs, endings otherwise."""
    forms = {inf}
    if inf in IRREGULAR and IRREGULAR[inf]:
        forms |= set(IRREGULAR[inf].split())
    stem = inf[:-2] if inf.endswith("en") else inf[:-1]
    if len(stem) >= 2:
        for e in ("e", "st", "t", "et", "est", "en", "te", "test", "ten", "tet", "etest", "eten", "ete"):
            forms.add(stem + e)
        forms.add(stem)
        forms.add("ge" + stem + "t")
        forms.add("ge" + stem + "et")
        forms.add("zu" + inf)
    return forms


def adjective_forms(lemma: str) -> set[str]:
    forms = {lemma}
    for e in ("e", "er", "es", "en", "em"):
        forms.add(lemma + e)
        forms.add(lemma + "er" + e)  # comparative
    forms.add(lemma + "er")
    forms.add(lemma + "st")
    return forms


def separable_split(inf: str) -> tuple[str, str] | None:
    for pre in sorted(SEPARABLE, key=len, reverse=True):
        rest = inf[len(pre):]
        if inf.startswith(pre) and len(rest) >= 4 and rest.endswith("en"):
            return pre, rest
    return None


def forms_of(w: dict, nouns: dict) -> tuple[set[str], str | None]:
    """Surface forms of a word for sentence matching, plus a required separable prefix."""
    lemma = w["l"]
    pos = w["pos"][0]
    if pos == "noun":
        info = w.get("_info")
        return ({lemma} | (info["forms"] if info else set())), None
    if pos == "verb":
        sep = separable_split(lemma)
        if sep:
            pre, rest = sep
            return verb_forms(rest), pre
        return verb_forms(lemma), None
    if pos == "adjective":
        return adjective_forms(lemma), None
    return {lemma, lemma.lower()}, None


# ----------------------------------------------------------------- tokenising
EDGE = re.compile(r"^[\s\"'„“”‚‘’«»()\[\]{}.,;:!?¿¡…–—-]+|[\s\"'„“”‚‘’«»()\[\]{}.,;:!?¿¡…–—-]+$")


def tokens(text: str) -> list[str]:
    out = []
    for raw in text.split():
        t = EDGE.sub("", raw)
        if t:
            out.append(t)
    return out


# ------------------------------------------------------------------- loading
def load_core() -> list[dict]:
    rows = []
    with open(os.path.join(SRC, "core.txt"), encoding="utf-8") as f:
        for n, line in enumerate(f):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("|")
            if len(parts) != 7:
                sys.exit(f"core.txt: bad line {line!r}")
            lvl, pos, word, meaning, de, en, note = parts
            rows.append({
                "lvl": AM_LEVEL[lvl], "pos": pos, "word": word, "m": split_meanings(meaning),
                "de": de, "en": en, "note": note, "order": n, "core": True,
            })
    return rows


def load_vocab_rows() -> list[dict]:
    rows = []
    for L in ["A1", "A2", "B1", "B2", "C1", "C2"]:
        with open(os.path.join(RAW, f"German_{L}.csv"), encoding="utf-8") as f:
            for r in csv.DictReader(f):
                pos = norm_pos(r["pos"])
                word = r["word"].strip()
                if not word or not pos or not r["english_translation"].strip():
                    continue
                if BLOCK.search(r["english_translation"]):
                    continue
                if re.search(r"[0-9.@/_]", word) or DE_BLOCK.search(word):
                    continue
                if pos != "noun" and word[0].isupper():
                    continue  # names and capitalised oddities
                if pos == "noun" and " " in word:
                    continue
                rows.append({
                    "lvl": AM_LEVEL[L], "pos": pos, "word": word,
                    "m": split_meanings(r["english_translation"]),
                    "de": r["example_sentence_de"].strip(), "en": r["example_sentence_en"].strip(),
                    "note": "", "core": False, "src_pos": r["pos"],
                })
    return rows


def make_word(row: dict, nouns: dict) -> dict | None:
    pos = row["pos"]
    word = row["word"]
    note = row["note"]
    entry = {"l": word, "m": row["m"], "pos": [pos]}
    if pos == "noun":
        info = pick_noun(nouns, word, row["de"])
        if not info or word in NOT_NOUNS:
            return None
        entry["_info"] = info
        art = ARTICLE[info["g"]]
        entry["s"] = f"{art} {word}"
        entry["g"] = art
        if info.get("plural_only"):
            note = "Plural only"
        elif info["plural"] and word not in NO_PLURAL:
            note = f"Plural: die {info['plural']}"
    else:
        entry["s"] = word
        if pos == "verb" and not note:
            sp = separable_split(word)
            if sp and "separable" in row.get("src_pos", "separable"):
                note = f"Separable verb: {sp[0]}-"
            elif row.get("src_pos", "").lower().startswith("reflexive"):
                note = "Reflexive verb"
    entry["x"] = note
    return entry


# ------------------------------------------------------------------- Tatoeba
def load_tatoeba():
    def read(name):
        path = os.path.join(RAW, name)
        if not os.path.exists(path):  # the English list is shared with other packs
            path = os.path.join(os.path.dirname(RAW), name)
        with bz2.open(path, "rt", encoding="utf-8") as f:
            for line in f:
                yield line.rstrip("\n").split("\t")

    deu = {}
    for row in read("deu_sentences.tsv.bz2"):
        if len(row) < 3:
            continue
        text = row[2].strip()
        if "\n" in text or len(text) > 110 or len(text) < 8:
            continue
        deu[int(row[0])] = text
    links = defaultdict(list)
    for row in read("deu-eng_links.tsv.bz2"):
        if len(row) < 2:
            continue
        a, b = int(row[0]), int(row[1])
        if a in deu:
            links[a].append(b)
    needed = {b for bs in links.values() for b in bs}
    eng = {}
    for row in read("eng_sentences.tsv.bz2"):
        if len(row) < 3:
            continue
        sid = int(row[0])
        if sid in needed:
            eng[sid] = row[2].strip()
    pairs = {}
    for a, bs in links.items():
        trans = sorted((eng[b] for b in bs if b in eng), key=len)
        if trans:
            pairs[a] = (deu[a], trans[0])
    log(f"tatoeba: {len(deu)} german sentences, {len(pairs)} with English")
    return pairs


def sentence_ok(text: str, level: int, targets: set[str]) -> bool:
    toks = tokens(text)
    max_len = {1: 7, 2: 9, 3: 12, 4: 15, 5: 18, 6: 20}[level]
    if not (3 <= len(toks) <= max_len):
        return False
    low = [t.lower() for t in toks]
    if any(t in NAMES for t in low) or DE_BLOCK.search(text):
        return False
    floor = {1: 3.7, 2: 3.5, 3: 3.0}.get(level)
    if floor:
        for t in low:
            if t in targets:
                continue
            if zipf_frequency(t, "de") < floor and not t.isdigit():
                return False
    return True


# -------------------------------------------------------------------- grammar
def load_grammar(lowercase_words: set[str]) -> list[dict]:
    """Authored grammar points (content_src/de/grammar_*.py), with tiles for order questions."""
    sys.path.insert(0, SRC)
    import importlib
    points: list[dict] = []
    for name in ("grammar_a1", "grammar_a2", "grammar_b1", "grammar_b2", "grammar_c"):
        points += importlib.import_module(name).POINTS
    ids = [p["id"] for p in points]
    assert len(ids) == len(set(ids)), "duplicate grammar ids"

    def tiles(s: str) -> list[str]:
        t = tokens(s)
        if t and t[0].lower() != t[0] and t[0].lower() in lowercase_words:
            t[0] = t[0].lower()
        return t

    for p in points:
        for q in p["quiz"]:
            if q["type"] == "order":
                q["tokens"] = tiles(q["answer"])
    log(f"grammar: {len(points)} points")
    return points


# ----------------------------------------------------------------------- main
def main() -> None:
    nouns = load_nouns()
    core = load_core()
    am = load_vocab_rows()
    core_lower = {r["word"].lower() for r in core}
    kept = []
    for r in am:
        w = r["word"]
        if r["pos"] != "noun" and w.lower() in core_lower:
            continue
        if "ss" in w and w.replace("ss", "ß") != w and zipf(w.replace("ss", "ß")) > zipf(w) + 0.8:
            continue  # Swiss spelling (dreissig) when the German one is far more common
        kept.append(r)
    am = kept
    log(f"vocabulary rows: {len(am)} (+{len(core)} core)")

    # ---- candidate words per level pool
    seen: set[str] = set()
    picked: dict[int, list[dict]] = {n: [] for n in range(1, 7)}

    def add(row: dict, level: int) -> bool:
        w = make_word(row, nouns)
        if not w:
            return False
        key = w["s"]
        if key in seen:
            return False
        seen.add(key)
        w["lvl"] = level
        w["_ai"] = (row["de"], row["en"])
        w["_core"] = row["core"]
        picked[level].append(w)
        return True

    group_rank = {"phrase": 0, "pronoun": 1, "number": 2}
    core_sorted = sorted(core, key=lambda r: (r["lvl"], group_rank.get(r["pos"], 3) if r["lvl"] == 1 else 3, r["order"]))
    for row in core_sorted:
        # core rows are written for the app; nouns need gender data, others pass through
        if row["pos"] == "noun" and row["word"] not in nouns and row["word"] not in PLURAL_ONLY:
            log(f"core noun without gender data: {row['word']}")
            continue
        add({**row, "pos": row["pos"] if row["pos"] != "determiner" else "other"}, row["lvl"])

    pools: dict[int, list[dict]] = defaultdict(list)
    for r in am:
        r["z"] = zipf(r["word"])
        pools[r["lvl"]].append(r)
    for p in pools.values():
        p.sort(key=lambda r: (-r["z"], r["word"]))

    def fill(level: int, pool_levels: list[int]) -> None:
        for pl in pool_levels:
            for r in pools[pl]:
                if len(picked[level]) >= QUOTA[level]:
                    return
                add(r, level)

    # Everyday basics that must not fall out of the quota (by topic checklist).
    must = {1: "Banane Kartoffel Tomate Nudel Durst Socke Pullover Hausaufgabe Formular Bäckerei".split(),
            2: "Cousin Speisekarte Mantel Gürtel Fahrkarte Gleis Feiertag Wolke Kuh Apotheke Medikament Tablette".split()}
    for level, lemmas in must.items():
        for lemma in lemmas:
            for r in am:
                if r["word"] == lemma and r["pos"] == "noun":
                    add(r, level)
                    break

    fill(1, [1])
    fill(2, [2])
    fill(3, [3])
    fill(4, [4])
    fill(5, [5])
    fill(6, [5, 6])
    # Top up levels the pool could not fill from the next pool down the line.
    for level in range(1, 7):
        if len(picked[level]) < QUOTA[level]:
            fill(level, [min(level + 1, 6)])

    words: list[dict] = []
    for level in range(1, 7):
        lw = picked[level]
        # Core words keep their authored order first; the rest by frequency.
        core_part = [w for w in lw if w["_core"]]
        rest = sorted((w for w in lw if not w["_core"]), key=lambda w: (-zipf(w["l"]), w["l"]))
        words.extend(core_part + rest)
        log(f"level {LEVELS[level - 1]}: {len(lw)} words ({len(core_part)} core)")
    for i, w in enumerate(words, start=1):
        w["id"] = i

    # ---- sentences: the word's own example first, then Tatoeba
    sentences: dict[int, dict] = {}
    chosen: dict[int, list[int]] = {}
    AI_BASE = 9_000_000
    form_index: dict[int, tuple[set[str], str | None]] = {}
    word_by_id = {w["id"]: w for w in words}
    for w in words:
        form_index[w["id"]] = forms_of(w, nouns)

    def matches(text: str, wid: int) -> bool:
        forms, prefix = form_index[wid]
        lemma = word_by_id[wid]["l"]
        if " " in lemma:  # phrases are matched as a whole
            return lemma.lower().replace("'", "'") in text.lower()
        toks = tokens(text)
        low = {t.lower() for t in toks}
        hit = any(t in forms or t.lower() in forms for t in toks)
        if not hit:
            return False
        return prefix is None or prefix in low or any(t.lower().startswith(prefix) for t in toks)

    ai_ok = 0
    for w in words:
        de, en = w["_ai"]
        chosen[w["id"]] = []
        if de and en and not DE_BLOCK.search(de) and matches(de, w["id"]):
            sid = AI_BASE + w["id"]
            sentences[sid] = {"id": sid, "t": de, "en": en, "r": "", "lvl": w["lvl"], "w": [w["id"]]}
            chosen[w["id"]].append(sid)
            ai_ok += 1
    log(f"own examples that contain the word: {ai_ok}/{len(words)}")

    pairs = load_tatoeba()
    by_token: dict[str, list[int]] = defaultdict(list)
    for sid, (de, _) in pairs.items():
        for t in set(tokens(de)):
            by_token[t].append(sid)
            by_token[t.lower()].append(sid)
    used_count: dict[int, int] = defaultdict(int)
    tat_hits = 0
    for w in words:
        forms, _ = form_index[w["id"]]
        cand: set[int] = set()
        for f in forms:
            cand.update(by_token.get(f, ()))
        targets = {f.lower() for f in forms}
        good = []
        for sid in cand:
            de, en = pairs[sid]
            if sentence_ok(de, w["lvl"], targets) and matches(de, w["id"]):
                good.append((used_count[sid], len(de), sid))
        good.sort()
        for _, _, sid in good[:2]:
            used_count[sid] += 1
            if sid not in sentences:
                de, en = pairs[sid]
                sentences[sid] = {"id": sid, "t": de, "en": en, "r": "", "lvl": w["lvl"], "w": []}
            sentences[sid]["w"].append(w["id"])
            chosen[w["id"]].append(sid)
        if good:
            tat_hits += 1
    log(f"words with a Tatoeba sentence: {tat_hits}/{len(words)}")
    # Order each word's examples: shortest first.
    for wid, ids in chosen.items():
        ids.sort(key=lambda s: len(sentences[s]["t"]))
    none = sum(1 for ids in chosen.values() if not ids)
    log(f"words without any example: {none}")

    # ---- grammar and path
    lowercase_words = {w["l"] for w in words if "g" not in w and w["l"] == w["l"].lower()}
    lowercase_words |= CLOSED_CLASS
    grammar = load_grammar(lowercase_words)
    out_words = []
    for w in words:
        o = {"id": w["id"], "s": w["s"], "y": "", "n": "", "m": w["m"], "pos": w["pos"],
             "lvl": w["lvl"], "ex": chosen[w["id"]]}
        if w["l"] != w["s"]:
            o["l"] = w["l"]
        if "g" in w:
            o["g"] = w["g"]
        if w["x"]:
            o["x"] = w["x"]
        out_words.append(o)

    levels = packlib.build_levels(
        "de", LEVELS, LEVEL_META, out_words, chosen, grammar,
        WORDS_PER_LESSON, VOCAB_MINUTES,
    )

    packlib.dump(os.path.join(OUT, "vocab.json"), out_words, ROOT)
    packlib.dump(os.path.join(OUT, "sentences.json"), sorted(sentences.values(), key=lambda s: s["id"]), ROOT)
    packlib.dump(os.path.join(OUT, "grammar.json"), grammar, ROOT)
    for lv in levels:
        packlib.dump(os.path.join(OUT, "levels", f"{lv['id']}.json"), lv, ROOT)
    with open(os.path.join(SRC, "pack.json"), encoding="utf-8") as f:
        pack = json.load(f)
    pack["levels"] = [{k: v for k, v in lv.items() if k != "units"} for lv in levels]
    pack["wordCount"] = len(out_words)
    pack["sentenceCount"] = len(sentences)
    pack["grammarCount"] = len(grammar)
    packlib.dump(os.path.join(OUT, "pack.json"), pack, ROOT)


if __name__ == "__main__":
    main()
