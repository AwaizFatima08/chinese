import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class SoundPair {
  const SoundPair({
    required this.a,
    required this.b,
    required this.ipaA,
    required this.ipaB,
  });

  factory SoundPair.fromJson(Map<String, dynamic> j) => SoundPair(
    a: j['a'] as String,
    b: j['b'] as String,
    ipaA: j['ia'] as String,
    ipaB: j['ib'] as String,
  );

  final String a;
  final String b;
  final String ipaA;
  final String ipaB;

  String ipaOf(String word) => word == a ? ipaA : ipaB;
  String otherOf(String word) => word == a ? b : a;
}

/// A contrast such as ship / sheep, with the pairs that train it.
@immutable
class SoundSet {
  const SoundSet({
    required this.id,
    required this.title,
    required this.symbols,
    required this.tip,
    required this.pairs,
    required this.phrases,
  });

  factory SoundSet.fromJson(Map<String, dynamic> j) => SoundSet(
    id: j['id'] as String,
    title: j['title'] as String,
    symbols: List<String>.from(j['symbols'] as List<dynamic>),
    tip: j['tip'] as String,
    pairs: [
      for (final p in j['pairs'] as List<dynamic>)
        SoundPair.fromJson(p as Map<String, dynamic>),
    ],
    phrases: List<String>.from(j['phrases'] as List<dynamic>),
  );

  final String id;
  final String title;
  final List<String> symbols;
  final String tip;
  final List<SoundPair> pairs;
  final List<String> phrases;
}

@immutable
class StressWord {
  const StressWord({
    required this.word,
    required this.syllables,
    required this.stress,
    required this.ipa,
    this.pos,
  });

  factory StressWord.fromJson(Map<String, dynamic> j) => StressWord(
    word: j['w'] as String,
    syllables: List<String>.from(j['syl'] as List<dynamic>),
    stress: j['stress'] as int,
    ipa: j['ipa'] as String,
    pos: j['pos'] as String?,
  );

  final String word;

  /// Syllables in IPA, each with its own stress mark if it has one.
  final List<String> syllables;

  /// 1-based number of the syllable with the main stress.
  final int stress;
  final String ipa;
  final String? pos;
}

@immutable
class StressSet {
  const StressSet({
    required this.id,
    required this.title,
    required this.tip,
    required this.words,
  });

  factory StressSet.fromJson(Map<String, dynamic> j) => StressSet(
    id: j['id'] as String,
    title: j['title'] as String,
    tip: j['tip'] as String,
    words: [
      for (final w in j['words'] as List<dynamic>)
        StressWord.fromJson(w as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final String tip;
  final List<StressWord> words;
}

@immutable
class VocabWord {
  const VocabWord({
    required this.id,
    required this.word,
    required this.pos,
    required this.definition,
    required this.example,
    required this.ipa,
  });

  factory VocabWord.fromJson(Map<String, dynamic> j) => VocabWord(
    id: j['id'] as int,
    word: j['w'] as String,
    pos: j['pos'] as String,
    definition: j['def'] as String,
    example: j['ex'] as String,
    ipa: j['ipa'] as String,
  );

  final int id;
  final String word;
  final String pos;
  final String definition;
  final String example;
  final String ipa;
}

@immutable
class VocabUnit {
  const VocabUnit({required this.id, required this.title, required this.words});

  factory VocabUnit.fromJson(Map<String, dynamic> j) => VocabUnit(
    id: j['id'] as String,
    title: j['title'] as String,
    words: [
      for (final w in j['words'] as List<dynamic>)
        VocabWord.fromJson(w as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final List<VocabWord> words;
}

@immutable
class ShadowSet {
  const ShadowSet({
    required this.id,
    required this.title,
    required this.tip,
    required this.items,
  });

  factory ShadowSet.fromJson(Map<String, dynamic> j) => ShadowSet(
    id: j['id'] as String,
    title: j['title'] as String,
    tip: j['tip'] as String,
    items: List<String>.from(j['items'] as List<dynamic>),
  );

  final String id;
  final String title;
  final String tip;
  final List<String> items;
}

@immutable
class Twister {
  const Twister({required this.id, required this.focus, required this.text});

  factory Twister.fromJson(Map<String, dynamic> j) => Twister(
    id: j['id'] as String,
    focus: j['focus'] as String,
    text: j['text'] as String,
  );

  final String id;
  final String focus;
  final String text;
}

/// One exchange in a role-play: the partner speaks, the learner replies.
@immutable
class TalkTurn {
  const TalkTurn({
    required this.say,
    required this.replies,
    required this.keywords,
  });

  factory TalkTurn.fromJson(Map<String, dynamic> j) => TalkTurn(
    say: j['say'] as String,
    replies: List<String>.from(j['replies'] as List<dynamic>),
    keywords: List<String>.from(j['keywords'] as List<dynamic>),
  );

  /// What the partner says.
  final String say;

  /// Model answers the learner can read out.
  final List<String> replies;

  /// Words that show a free answer is on topic.
  final List<String> keywords;
}

/// A short scripted role-play (ordering coffee, a job interview, ...).
@immutable
class Talk {
  const Talk({
    required this.id,
    required this.title,
    required this.partner,
    required this.setting,
    required this.phrases,
    required this.turns,
  });

  factory Talk.fromJson(Map<String, dynamic> j) => Talk(
    id: j['id'] as String,
    title: j['title'] as String,
    partner: j['partner'] as String,
    setting: j['setting'] as String,
    phrases: List<String>.from(j['phrases'] as List<dynamic>),
    turns: [
      for (final t in j['turns'] as List<dynamic>)
        TalkTurn.fromJson(t as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final String partner;
  final String setting;
  final List<String> phrases;
  final List<TalkTurn> turns;
}

/// What a practice set trains; also its section on the Speak tab.
enum SetKind { sounds, stress, vocab, shadow, twister, talk, review }

/// One short practice session shown on the Speak tab.
@immutable
class PracticeSet {
  const PracticeSet({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.minutes = 5,
  });

  /// Unique and stable: it is the key under which stars are saved.
  final String id;
  final SetKind kind;
  final String title;
  final String subtitle;
  final int minutes;
}

/// A heading with its sets on the Speak tab.
@immutable
class PracticeGroup {
  const PracticeGroup({
    required this.kind,
    required this.sets,
    this.unitTitles = const {},
  });

  final SetKind kind;
  final List<PracticeSet> sets;

  /// For vocabulary: set id prefix -> unit title.
  final Map<String, String> unitTitles;
}

/// All spoken-English practice content, loaded from `assets/speak/`.
class SpeakContent {
  SpeakContent({
    required this.sounds,
    required this.stress,
    required this.vocab,
    required this.shadow,
    required this.twisters,
    this.talks = const [],
  }) : _wordsById = {
         for (final u in vocab)
           for (final w in u.words) w.id: w,
       };

  final List<SoundSet> sounds;
  final List<StressSet> stress;
  final List<VocabUnit> vocab;
  final List<ShadowSet> shadow;
  final List<Twister> twisters;
  final List<Talk> talks;
  final Map<int, VocabWord> _wordsById;

  /// Words per vocabulary practice set, and twisters per set.
  static const wordsPerPart = 5;
  static const twistersPerSet = 3;

  static Future<SpeakContent> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    Future<List<dynamic>> read(String name) async =>
        jsonDecode(await b.loadString('assets/speak/$name.json'))
            as List<dynamic>;
    final sounds = await read('sounds');
    final stress = await read('stress');
    final vocab = await read('vocab');
    final shadow = await read('sentences');
    final twisters = await read('twisters');
    final talks = await read('talks');
    return SpeakContent(
      sounds: [
        for (final j in sounds) SoundSet.fromJson(j as Map<String, dynamic>),
      ],
      stress: [
        for (final j in stress) StressSet.fromJson(j as Map<String, dynamic>),
      ],
      vocab: [
        for (final j in vocab) VocabUnit.fromJson(j as Map<String, dynamic>),
      ],
      shadow: [
        for (final j in shadow) ShadowSet.fromJson(j as Map<String, dynamic>),
      ],
      twisters: [
        for (final j in twisters) Twister.fromJson(j as Map<String, dynamic>),
      ],
      talks: [for (final j in talks) Talk.fromJson(j as Map<String, dynamic>)],
    );
  }

  VocabWord? wordById(int id) => _wordsById[id];

  int get vocabWordCount => _wordsById.length;

  SoundSet? soundSet(String id) => _firstWhere(sounds, (s) => s.id == id);
  StressSet? stressSet(String id) => _firstWhere(stress, (s) => s.id == id);
  ShadowSet? shadowSet(String id) => _firstWhere(shadow, (s) => s.id == id);
  VocabUnit? vocabUnit(String id) => _firstWhere(vocab, (s) => s.id == id);
  Talk? talk(String id) => _firstWhere(talks, (s) => s.id == id);

  static T? _firstWhere<T>(List<T> list, bool Function(T) test) {
    for (final e in list) {
      if (test(e)) return e;
    }
    return null;
  }

  /// The practice sets in the order they are offered.
  List<PracticeGroup> get groups {
    final partsPerUnit = <String, int>{};
    final vocabSets = <PracticeSet>[];
    final unitTitles = <String, String>{};
    for (final u in vocab) {
      final parts = (u.words.length / wordsPerPart).ceil();
      partsPerUnit[u.id] = parts;
      unitTitles['voc:${u.id}'] = u.title;
      for (var p = 1; p <= parts; p++) {
        final from = (p - 1) * wordsPerPart;
        final to = from + wordsPerPart > u.words.length
            ? u.words.length
            : from + wordsPerPart;
        vocabSets.add(
          PracticeSet(
            id: 'voc:${u.id}:$p',
            kind: SetKind.vocab,
            title: '${u.title} · $p',
            subtitle: u.words.sublist(from, to).map((w) => w.word).join(', '),
          ),
        );
      }
    }
    final twisterSets = <PracticeSet>[];
    for (var i = 0; i * twistersPerSet < twisters.length; i++) {
      final from = i * twistersPerSet;
      final to = from + twistersPerSet > twisters.length
          ? twisters.length
          : from + twistersPerSet;
      twisterSets.add(
        PracticeSet(
          id: 'tw:${i + 1}',
          kind: SetKind.twister,
          title: '${i + 1}',
          subtitle: twisters.sublist(from, to).map((t) => t.focus).join(' · '),
          minutes: 4,
        ),
      );
    }
    return [
      PracticeGroup(
        kind: SetKind.sounds,
        sets: [
          for (final s in sounds)
            PracticeSet(
              id: 'snd:${s.id}',
              kind: SetKind.sounds,
              title: s.title,
              subtitle: s.symbols.map((x) => '/$x/').join('  '),
            ),
        ],
      ),
      PracticeGroup(
        kind: SetKind.stress,
        sets: [
          for (final s in stress)
            PracticeSet(
              id: 'str:${s.id}',
              kind: SetKind.stress,
              title: s.title,
              subtitle: s.words.take(4).map((w) => w.word).join(', '),
            ),
        ],
      ),
      PracticeGroup(
        kind: SetKind.vocab,
        sets: vocabSets,
        unitTitles: unitTitles,
      ),
      PracticeGroup(
        kind: SetKind.shadow,
        sets: [
          for (final s in shadow)
            PracticeSet(
              id: 'sh:${s.id}',
              kind: SetKind.shadow,
              title: s.title,
              subtitle: s.items.first,
            ),
        ],
      ),
      PracticeGroup(kind: SetKind.twister, sets: twisterSets),
      PracticeGroup(
        kind: SetKind.talk,
        sets: [
          for (final t in talks)
            PracticeSet(
              id: 'talk:${t.id}',
              kind: SetKind.talk,
              title: t.title,
              subtitle: t.setting,
              minutes: 6,
            ),
        ],
      ),
    ];
  }

  /// Every set id, for tests and checks.
  Iterable<PracticeSet> get allSets => groups.expand((g) => g.sets);
}
