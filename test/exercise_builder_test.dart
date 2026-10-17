import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/features/lesson/exercise.dart';
import 'package:lingodaily/features/lesson/exercise_builder.dart';
import 'package:lingodaily/languages/language_content.dart';
import 'package:lingodaily/languages/models.dart';
import 'package:lingodaily/languages/language_tools.dart';

import 'helpers/file_bundle.dart';

/// Rough seconds a learner spends on each kind of step.
int seconds(Exercise e) => switch (e) {
  IntroExercise() => 18,
  ChoiceExercise() => 9,
  SpeakExercise() => 20,
  WriteExercise() => 55,
  TypeExercise() => 30,
  SentenceChoiceExercise() => 20,
  OrderExercise() => 28,
  ShadowExercise() => 22,
  GrammarExplainExercise() => 60,
  GrammarChoiceExercise() => 14,
};

void main() {
  for (final lang in ['zh', 'de']) {
    group('pack $lang', () => packTests(lang));
  }
  germanTests();
}

void germanTests() {
  group('German specifics', () {
    late LanguageContent content;
    late ExerciseBuilder builder;

    setUpAll(() async {
      content = await LanguageContent.load('de', bundle: FileAssetBundle());
      builder = ExerciseBuilder(
        content,
        LanguageTools.forPack(content.pack, content.words.values),
      );
    });

    test('nouns carry article, lemma and plural note', () {
      final nouns = content.allWords.where((w) => w.article != null);
      expect(nouns.length, greaterThan(2500));
      for (final w in nouns.take(300)) {
        expect(w.text, '${w.article} ${w.lemma}');
        expect(const {'der', 'die', 'das'}, contains(w.article));
      }
      final withPlural = nouns.where((w) => w.note.startsWith('Plural: die '));
      expect(withPlural.length, greaterThan(nouns.length * 0.8));
    });

    test('every word has a meaning; no German pack word has romanization', () {
      for (final w in content.allWords) {
        expect(w.meanings, isNotEmpty, reason: w.text);
        expect(w.romanization, isEmpty);
      }
    });

    test('vocabulary lessons practise articles and spelling, not strokes', () {
      var articles = 0;
      var typed = 0;
      var strokes = 0;
      for (final lesson in content.levelByNumber(1)!.lessons) {
        if (lesson.type != LessonType.vocab) continue;
        final ex = builder.forLesson(lesson, seed: 7);
        articles += ex
            .whereType<ChoiceExercise>()
            .where((e) => e.kind == ChoiceKind.article)
            .length;
        typed += ex.whereType<TypeExercise>().length;
        strokes += ex.whereType<WriteExercise>().length;
        expect(
          ex.whereType<ChoiceExercise>().where(
            (e) => e.kind == ChoiceKind.listenRomanization,
          ),
          isEmpty,
        );
      }
      expect(articles, greaterThan(40));
      expect(typed, greaterThan(100));
      expect(strokes, 0);
    });

    test('article questions have der, die, das and one right answer', () {
      final lesson = content
          .levelByNumber(2)!
          .lessons
          .firstWhere((l) => l.type == LessonType.vocab);
      final ex = builder
          .forLesson(lesson, seed: 3)
          .whereType<ChoiceExercise>()
          .where((e) => e.kind == ChoiceKind.article);
      for (final e in ex) {
        expect(e.options, ['der', 'die', 'das']);
        expect(e.options[e.answerIndex], e.word.article);
      }
    });
  });
}

void packTests(String lang) {
  late LanguageContent content;
  late ExerciseBuilder builder;

  setUpAll(() async {
    content = await LanguageContent.load(lang, bundle: FileAssetBundle());
    builder = ExerciseBuilder(
      content,
      LanguageTools.forPack(content.pack, content.words.values),
    );
  });

  test('content loads with the expected shape', () {
    expect(content.pack.levels.length, 6);
    if (lang == 'zh') {
      expect(content.words.length, greaterThan(4900));
      expect(content.grammar.length, 62);
      expect(content.levels['hsk1']!.lessons.length, 34);
    } else {
      expect(content.words.length, greaterThan(5500));
      expect(content.grammar.length, 60);
      expect(content.levelByNumber(1)!.info.id, 'a1');
    }
  });

  test(
    'every lesson of every level builds valid exercises within 15 minutes',
    () {
      final over = <String>[];
      var lessons = 0;
      final byType = <LessonType, List<int>>{};
      for (final level in content.levels.values) {
        for (final lesson in level.lessons) {
          lessons++;
          final ex = builder.forLesson(lesson, seed: lesson.id.hashCode);
          expect(ex, isNotEmpty, reason: lesson.id);
          for (final e in ex) {
            if (e is ChoiceExercise) {
              expect(
                e.options.length,
                greaterThanOrEqualTo(3),
                reason: '${lesson.id} ${e.kind} ${e.word.text}',
              );
              expect(
                e.options.toSet().length,
                e.options.length,
                reason: '${lesson.id} ${e.kind} ${e.word.text} ${e.options}',
              );
              expect(e.answerIndex, inInclusiveRange(0, e.options.length - 1));
            }
            if (e is SentenceChoiceExercise) {
              expect(e.options[e.answerIndex], e.sentence.translation);
              expect(e.options.length, greaterThanOrEqualTo(3));
            }
            if (e is OrderExercise) {
              expect(e.bank.toList()..sort(), e.answerTiles.toList()..sort());
            }
            if (e is GrammarChoiceExercise) {
              expect(e.answerIndex, isNonNegative);
            }
          }
          final total = ex.fold<int>(0, (a, e) => a + seconds(e));
          byType.putIfAbsent(lesson.type, () => []).add(total);
          if (total > 15 * 60) over.add('${lesson.id}: ${total ~/ 60} min');
        }
      }
      for (final e in byType.entries) {
        final list = e.value..sort();
        // ignore: avoid_print
        print(
          '${e.key.name}: n=${list.length} min=${list.first ~/ 60}m '
          'median=${list[list.length ~/ 2] ~/ 60}m max=${list.last ~/ 60}m',
        );
      }
      // ignore: avoid_print
      print('$lessons lessons, over 15 min: $over');
      expect(over, isEmpty);
    },
  );

  test('same seed gives the same lesson', () {
    final lesson = content.levelByNumber(1)!.lessons.first;
    String sig(List<Exercise> l) => l.map((e) => e.runtimeType).join(',');
    expect(
      sig(builder.forLesson(lesson, seed: 5)),
      sig(builder.forLesson(lesson, seed: 5)),
    );
  });

  test('review builds a choice per word', () {
    final ex = builder.forReview([1, 2, 3, 4, 5], seed: 1);
    expect(ex.whereType<ChoiceExercise>().length, 5);
  });
}
