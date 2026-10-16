import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/core/services/ad_service.dart';
import 'package:lingodaily/data/progress_models.dart';
import 'package:lingodaily/data/progress_repository.dart';
import 'package:lingodaily/data/srs.dart';

void main() {
  group('spaced repetition', () {
    test('a new word learned cleanly lands in box 1, due tomorrow', () {
      final p = applyFirstLearning(
        null,
        wordId: 1,
        outcome: WordOutcome.clean,
        today: 100,
      );
      expect(p.box, 1);
      expect(p.dueDay, 101);
      expect(p.isLearned, isTrue);
    });

    test('a shaky first learning stays in box 0', () {
      final p = applyFirstLearning(
        null,
        wordId: 1,
        outcome: WordOutcome.shaky,
        today: 100,
      );
      expect(p.box, 0);
      expect(p.isLearned, isFalse);
      expect(p.lapses, 1);
    });

    test('correct reviews climb the boxes with growing gaps', () {
      WordProgress? p = applyFirstLearning(
        null,
        wordId: 1,
        outcome: WordOutcome.clean,
        today: 0,
      );
      var day = 1;
      final gaps = <int>[];
      for (var i = 0; i < 6; i++) {
        p = applyReview(p, wordId: 1, correct: true, today: day);
        gaps.add(p.dueDay - day);
        day = p.dueDay;
      }
      expect(p!.box, 6);
      expect(gaps.first, lessThan(gaps.last));
      expect(gaps, [3, 7, 14, 30, 60, 60]);
    });

    test('a wrong answer drops two boxes and comes back tomorrow', () {
      const known = WordProgress(
        wordId: 1,
        box: 5,
        dueDay: 10,
        reps: 5,
        lapses: 0,
        lastDay: 9,
      );
      final p = applyReview(known, wordId: 1, correct: false, today: 10);
      expect(p.box, 3);
      expect(p.lapses, 1);
      final low = applyReview(
        const WordProgress(
          wordId: 1,
          box: 1,
          dueDay: 10,
          reps: 1,
          lapses: 0,
          lastDay: 9,
        ),
        wordId: 1,
        correct: false,
        today: 10,
      );
      expect(low.box, 0);
    });
  });

  group('streak', () {
    test('counts consecutive study days ending today', () {
      expect(
        computeStreak(today: 10, practiceDays: {8, 9, 10}, freezeDays: {}),
        3,
      );
    });

    test('keeps the streak alive until the end of today', () {
      expect(
        computeStreak(today: 10, practiceDays: {7, 8, 9}, freezeDays: {}),
        3,
      );
    });

    test('breaks after a missed day', () {
      expect(computeStreak(today: 10, practiceDays: {7, 8}, freezeDays: {}), 0);
    });

    test('a freeze bridges the gap without adding a day', () {
      expect(
        computeStreak(today: 10, practiceDays: {7, 8, 10}, freezeDays: {9}),
        3,
      );
    });

    test('offers a repair only for a real, freshly broken streak', () {
      expect(
        missedDayToRepair(today: 10, practiceDays: {7, 8}, freezeDays: {}),
        9,
      );
      expect(
        missedDayToRepair(today: 10, practiceDays: {8, 9}, freezeDays: {}),
        -1,
      );
      expect(
        missedDayToRepair(today: 10, practiceDays: {1, 2}, freezeDays: {}),
        -1,
      );
      expect(
        missedDayToRepair(today: 10, practiceDays: {10}, freezeDays: {}),
        -1,
      );
    });

    test('day numbers ignore the time of day', () {
      expect(
        dayNumber(DateTime(2026, 10, 17, 0, 1)),
        dayNumber(DateTime(2026, 10, 17, 23, 59)),
      );
      expect(
        dayNumber(DateTime(2026, 10, 18)) - dayNumber(DateTime(2026, 10, 17)),
        1,
      );
    });
  });

  group('interstitial policy', () {
    const policy = InterstitialPolicy();
    final now = DateTime(2026, 10, 17, 12);

    test('never after the first lesson of the day', () {
      expect(
        policy.shouldShow(
          lessonsCompletedToday: 1,
          lessonsSinceLastAd: 5,
          now: now,
          lastShown: null,
        ),
        isFalse,
      );
    });

    test('needs two lessons since the last ad', () {
      expect(
        policy.shouldShow(
          lessonsCompletedToday: 3,
          lessonsSinceLastAd: 1,
          now: now,
          lastShown: null,
        ),
        isFalse,
      );
      expect(
        policy.shouldShow(
          lessonsCompletedToday: 3,
          lessonsSinceLastAd: 2,
          now: now,
          lastShown: null,
        ),
        isTrue,
      );
    });

    test('respects the minimum gap', () {
      expect(
        policy.shouldShow(
          lessonsCompletedToday: 4,
          lessonsSinceLastAd: 2,
          now: now,
          lastShown: now.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
      expect(
        policy.shouldShow(
          lessonsCompletedToday: 4,
          lessonsSinceLastAd: 2,
          now: now,
          lastShown: now.subtract(const Duration(minutes: 10)),
        ),
        isTrue,
      );
    });
  });
}
