"""Tiny helpers to author German grammar points as Python data.

A point has an explanation (English), a pattern, three examples and a quiz.
Multiple-choice options are written with the correct answer FIRST; the app
shuffles them. Word-order questions give the English sentence and the German
answer; the tiles are derived from the answer by scripts/build_content_de.py.
"""


def point(pid, lvl, title, pattern, explanation, examples, quiz):
    assert 3 <= len(examples) <= 4, pid
    assert 3 <= len(quiz) <= 4, pid
    return {
        "id": pid,
        "lvl": lvl,
        "title": title,
        "pattern": pattern,
        "explanation": explanation,
        "examples": [{"t": de, "en": en} for de, en in examples],
        "quiz": quiz,
    }


def mc(prompt, correct, *wrong):
    assert len(wrong) >= 2, prompt
    return {"type": "mc", "prompt": prompt, "options": [correct, *wrong], "answer": 0}


def order(en, answer):
    return {"type": "order", "en": en, "answer": answer}
