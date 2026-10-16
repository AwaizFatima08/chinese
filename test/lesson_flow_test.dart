import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/core/providers.dart';
import 'package:lingodaily/features/lesson/exercise.dart';
import 'package:lingodaily/features/lesson/session.dart';
import 'package:lingodaily/features/progress/progress_state.dart';

import 'helpers/test_app.dart';

const lessonId = 'zh-hsk1-u01-l01';

/// Plays a whole session; [wrongOn] decides which scored exercises to miss.
Future<void> play(
  ProviderContainer c,
  TestClock time,
  SessionRequest request, {
  bool Function(Exercise)? wrongOn,
}) async {
  final sub = c.listen(sessionProvider(request), (_, _) {});
  final notifier = c.read(sessionProvider(request).notifier);
  var guard = 0;
  while (!c.read(sessionProvider(request)).finished && guard++ < 500) {
    final ex = c.read(sessionProvider(request)).current!;
    time.now = time.now.add(const Duration(seconds: 12));
    if (ex.needsAnswer) {
      final wrong = wrongOn?.call(ex) ?? false;
      notifier.answered(correct: !wrong);
    }
    notifier.next();
  }
  sub.close();
}

void main() {
  test('finishing a vocabulary lesson saves words, stars and time', () async {
    final t = await makeContainer();
    final c = t.container;
    addTearDown(c.dispose);
    await c.read(contentProvider.future);
    await c.read(progressProvider.future);

    final request = SessionRequest.lesson(lessonId, seed: 3);
    await play(c, t.time, request);
    final result = c
        .read(sessionProvider(request).notifier)
        .result(completed: true);
    expect(result.stars, 3);
    expect(result.accuracy, 1);
    expect(result.outcomes.length, 7);
    expect(result.outcomes.values.every((o) => o.name == 'clean'), isTrue);
    expect(
      result.charactersWritten.length,
      3,
      reason: 'the three traced characters are recorded',
    );

    await c.read(progressProvider.notifier).saveSession(result);
    final p = c.read(progressProvider).value!;
    expect(p.isLessonDone(lessonId), isTrue);
    expect(p.lessons[lessonId]!.stars, 3);
    expect(p.learnedCount, 7);
    expect(p.todayLog.lessons, 1);
    expect(p.todayLog.seconds, greaterThan(60));
    expect(p.streak, 1);
    expect(p.dueCount, 0, reason: 'new words come back tomorrow');
  });

  test('wrong answers come back once and make the word shaky', () async {
    final t = await makeContainer();
    final c = t.container;
    addTearDown(c.dispose);
    await c.read(contentProvider.future);
    await c.read(progressProvider.future);

    final request = SessionRequest.lesson(lessonId, seed: 3);
    final base = c.read(sessionProvider(request)).queue.length;
    var missed = false;
    await play(
      c,
      t.time,
      request,
      wrongOn: (ex) {
        if (!missed && ex is ChoiceExercise) {
          missed = true;
          return true;
        }
        return false;
      },
    );
    final s = c.read(sessionProvider(request));
    expect(s.queue.length, base + 1, reason: 'one retry appended');
    expect(s.wrong, 1);
    final result = c
        .read(sessionProvider(request).notifier)
        .result(completed: true);
    expect(result.accuracy, lessThan(1));
    expect(result.outcomes.values.where((o) => o.name == 'shaky').length, 1);

    // The shaky word is not "learned" yet, but it must come back for review.
    await c.read(progressProvider.notifier).saveSession(result);
    final p = c.read(progressProvider).value!;
    expect(p.learnedCount, 6);
    t.time.now = DateTime(2026, 10, 18, 9);
    c.invalidate(progressProvider);
    final tomorrow = await c.read(progressProvider.future);
    expect(tomorrow.dueCount, 7, reason: 'all seven words, shaky one included');
  });

  test('next-day review surfaces the words and moves them up a box', () async {
    final t = await makeContainer();
    final c = t.container;
    addTearDown(c.dispose);
    await c.read(contentProvider.future);
    await c.read(progressProvider.future);

    final lesson = SessionRequest.lesson(lessonId, seed: 1);
    await play(c, t.time, lesson);
    await c
        .read(progressProvider.notifier)
        .saveSession(
          c.read(sessionProvider(lesson).notifier).result(completed: true),
        );

    // Tomorrow.
    t.time.now = DateTime(2026, 10, 18, 9);
    c.invalidate(progressProvider);
    final p = await c.read(progressProvider.future);
    expect(p.dueCount, 7);
    expect(p.streak, 1, reason: 'yesterday still counts until today ends');

    final review = SessionRequest.review(seed: 2);
    await play(c, t.time, review);
    final r = c.read(sessionProvider(review).notifier).result(completed: true);
    expect(r.lessonId, isNull);
    expect(r.correctByWord.length, 7);
    await c.read(progressProvider.notifier).saveSession(r);
    final after = c.read(progressProvider).value!;
    expect(after.dueCount, 0);
    expect(after.words.values.every((w) => w.box == 2), isTrue);
    expect(after.todayLog.reviews, 1);
    expect(after.streak, 2);
  });

  test(
    'leaving early keeps words already met but does not finish the lesson',
    () async {
      final t = await makeContainer();
      final c = t.container;
      addTearDown(c.dispose);
      await c.read(contentProvider.future);
      await c.read(progressProvider.future);

      final request = SessionRequest.lesson(lessonId, seed: 4);
      final sub = c.listen(sessionProvider(request), (_, _) {});
      addTearDown(sub.close);
      final n = c.read(sessionProvider(request).notifier);
      // Meet the first two words, then leave.
      for (var i = 0; i < 2; i++) {
        t.time.now = t.time.now.add(const Duration(seconds: 20));
        n.next();
      }
      final r = n.result(completed: false);
      expect(r.completed, isFalse);
      expect(r.outcomes.length, 2);
      await c.read(progressProvider.notifier).saveSession(r);
      final p = c.read(progressProvider).value!;
      expect(p.isLessonDone(lessonId), isFalse);
      expect(p.learnedCount, 2);
      expect(p.todayLog.seconds, greaterThan(0));
    },
  );

  test('grammar and checkpoint lessons complete too', () async {
    final t = await makeContainer();
    final c = t.container;
    addTearDown(c.dispose);
    final content = await c.read(contentProvider.future);
    await c.read(progressProvider.future);
    for (final id in ['zh-hsk1-u01-g', 'zh-hsk1-u01-c']) {
      expect(content.lessonById(id), isNotNull);
      final request = SessionRequest.lesson(id, seed: 9);
      await play(c, t.time, request);
      final r = c
          .read(sessionProvider(request).notifier)
          .result(completed: true);
      expect(r.stars, 3, reason: id);
      await c.read(progressProvider.notifier).saveSession(r);
      expect(c.read(progressProvider).value!.isLessonDone(id), isTrue);
    }
  });
}
