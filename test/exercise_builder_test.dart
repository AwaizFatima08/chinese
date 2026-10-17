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
  late LanguageContent content;
  late ExerciseBuilder builder;

  setUpAll(() async {
    content = await LanguageContent.load('zh', bundle: FileAssetBundle());
    builder = ExerciseBuilder(
      content,
      LanguageTools.forPack(content.pack, content.words.values),
    );
  });

  test('content loads with the expected shape', () {
    expect(content.pack.levels.length, 6);
    expect(content.words.length, greaterThan(4900));
    expect(content.grammar.length, 62);
    expect(content.levels['hsk1']!.lessons.length, 34);
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
    final lesson = content.levels['hsk1']!.lessons.first;
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
