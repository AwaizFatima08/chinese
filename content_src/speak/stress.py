"""Word-stress practice. Authored for HomiLabs (own text).

STRESS_SETS: id, title, tip, words. A word is either "word" (stress taken from the
dictionary) or ("word", stressed_syllable_number, "noun"/"verb") to choose between
dictionary variants, as in REcord (noun) and reCORD (verb)."""

STRESS = [
 dict(id="two-syl", title="Two-syllable words", tip="Most two-syllable nouns and adjectives are stressed on the first syllable; most verbs on the second.",
  words=["table","city","water","happy","number","reason","moment","problem","reply","decide","believe","prepare"]),
 dict(id="noun-verb", title="Noun or verb?", tip="Many two-syllable words change stress: the noun is stressed on the first syllable, the verb on the second.",
  words=[("record",1,"noun"),("record",2,"verb"),("present",1,"noun"),("present",2,"verb"),("object",1,"noun"),("object",2,"verb"),
         ("permit",1,"noun"),("permit",2,"verb"),("increase",1,"noun"),("increase",2,"verb"),("contest",1,"noun"),("contest",2,"verb"),
         ("produce",1,"noun"),("produce",2,"verb"),("conduct",1,"noun"),("conduct",2,"verb")]),
 dict(id="word-family", title="Word families", tip="When a word takes an ending, the stress often moves. The stress sits just before endings like -tion, -ic, -ity, -ical.",
  words=["photograph","photography","photographic","economy","economic","economical","politics","political","politician",
         "category","categorical","personal","personality","analyze","analysis","analytical"]),
 dict(id="long-words", title="Longer words", tip="In long words, find the main stress first and say the other syllables lightly. Unstressed vowels often become a short 'uh' (schwa).",
  words=["development","information","education","important","particular","comfortable","vegetable","necessary","temperature","communication",
         "opportunity","responsibility","environment","international","literature","laboratory"]),
 dict(id="tricky", title="Words people mispronounce", tip="Some words lose a syllable in everyday speech, or hide a silent letter. Listen first, then match the rhythm.",
  words=["interesting","family","chocolate","different","vegetable","comfortable","February","library","wednesday","business","average","restaurant","separate","temperature","probably","literature"]),
 dict(id="compounds", title="Compounds and phrases", tip="In compound nouns the first part carries the stress (BLACKboard), but in an adjective plus noun both are heard with the stress on the noun (black BOARD).",
  words=["blackboard","greenhouse","airport","bookshop","headache","toothpaste","sunrise","notebook","website","password","timetable","earthquake"]),
]
