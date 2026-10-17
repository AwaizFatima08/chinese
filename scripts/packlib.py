"""Shared helpers for building a language content pack (see docs/add-a-language.md).

`build_levels` turns an ordered word list into the learning path: levels →
units (four vocabulary lessons, an optional grammar lesson and a checkpoint) →
lessons. Lesson ids are stored in learners' progress, so the output must stay
deterministic for the same input.
"""
from __future__ import annotations

import json
import math
import os
import sys
from collections import defaultdict

VOCAB_LESSONS_PER_UNIT = 4


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def dump(path: str, obj, root: str | None = None) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, separators=(",", ":"))
    shown = os.path.relpath(path, root) if root else path
    log(f"wrote {shown} ({os.path.getsize(path) // 1024} KB)")


def build_levels(
    lang: str,
    level_ids: list[str],
    level_meta: dict[int, tuple[str, str, str]],
    words: list[dict],
    chosen: dict[int, list[int]],
    grammar: list[dict],
    words_per_lesson: dict[int, int],
    vocab_minutes: dict[int, int],
    subtitle_of=lambda w: w["s"],
) -> list[dict]:
    """Builds every level of a pack.

    words: dicts with at least id, s, lvl (1-based level number), in teaching order.
    chosen: word id -> example sentence ids.
    grammar: authored points with "lvl", "id" and "title".
    """
    levels = []
    grammar_by_level = defaultdict(list)
    for g in grammar:
        grammar_by_level[g["lvl"]].append(g)
    for number, level_id in enumerate(level_ids, start=1):
        lw = [w for w in words if w["lvl"] == number]
        per = words_per_lesson[number]
        n_vocab = math.ceil(len(lw) / per)
        n_units = math.ceil(n_vocab / VOCAB_LESSONS_PER_UNIT)
        gpts = grammar_by_level.get(number, [])
        g_per_unit = math.ceil(len(gpts) / n_units) if gpts else 0
        units = []
        wi = gi = lesson_no = 0
        for u in range(1, n_units + 1):
            lessons = []
            unit_words: list[int] = []
            for _ in range(VOCAB_LESSONS_PER_UNIT):
                if wi >= len(lw):
                    break
                chunk = lw[wi:wi + per]
                wi += len(chunk)
                lesson_no += 1
                unit_words += [w["id"] for w in chunk]
                sents: list[int] = []
                for w in chunk:
                    sents += chosen[w["id"]][:2]
                lessons.append({
                    "id": f"{lang}-{level_id}-u{u:02d}-l{len(lessons) + 1:02d}",
                    "type": "vocab",
                    "title": f"Lesson {lesson_no}",
                    "subtitle": " · ".join(subtitle_of(w) for w in chunk[:4])
                    + (" …" if len(chunk) > 4 else ""),
                    "words": [w["id"] for w in chunk],
                    "sentences": sents,
                    "minutes": vocab_minutes[number],
                })
            if g_per_unit and gi < len(gpts):
                pts = gpts[gi:gi + g_per_unit]
                gi += len(pts)
                lessons.append({
                    "id": f"{lang}-{level_id}-u{u:02d}-g",
                    "type": "grammar",
                    "title": "Grammar",
                    "subtitle": " · ".join(p["title"] for p in pts),
                    "grammar": [p["id"] for p in pts],
                    "words": [],
                    "sentences": [],
                    "minutes": 6,
                })
            lessons.append({
                "id": f"{lang}-{level_id}-u{u:02d}-c",
                "type": "checkpoint",
                "title": "Checkpoint",
                "subtitle": f"Unit {u} review",
                "words": unit_words,
                "sentences": [],
                "minutes": 4,
            })
            units.append({
                "id": f"{lang}-{level_id}-u{u:02d}",
                "title": f"Unit {u}",
                "lessons": lessons,
            })
        name, title, desc = level_meta[number]
        n_lessons = sum(len(u["lessons"]) for u in units)
        levels.append({
            "id": level_id, "number": number, "name": name, "title": title,
            "description": desc, "wordCount": len(lw),
            "unitCount": len(units), "lessonCount": n_lessons,
            "units": units,
        })
        log(f"path: {name} {len(lw)} words → {len(units)} units, {n_lessons} lessons")
    return levels
