import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/core/providers.dart';
import 'package:lingodaily/data/app_database.dart';
import 'package:lingodaily/data/backup.dart';
import 'package:lingodaily/data/progress_models.dart';
import 'package:lingodaily/data/progress_repository.dart';
import 'package:lingodaily/features/account/account_controller.dart';
import 'package:lingodaily/features/progress/progress_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/fake_cloud.dart';
import 'helpers/test_app.dart';

WordProgress word(int id, {int box = 1, int last = 10, int reps = 1}) =>
    WordProgress(
      wordId: id,
      box: box,
      dueDay: last + 2,
      reps: reps,
      lapses: 0,
      lastDay: last,
    );

LessonResult lesson(String id, int stars, int day, int attempts) =>
    LessonResult(
      lessonId: id,
      stars: stars,
      completedDay: day,
      attempts: attempts,
    );

void main() {
  sqfliteFfiInit();

  group('merge', () {
    test('keeps the word studied most recently', () {
      final a = LanguageBackup(words: {1: word(1, last: 10), 2: word(2)});
      final b = LanguageBackup(words: {1: word(1, box: 4, last: 12)});
      final m = LanguageBackup.merge(a, b);
      expect(m.words[1]!.box, 4);
      expect(m.words.keys, {1, 2});
      // Same answer the other way round.
      expect(LanguageBackup.merge(b, a).words[1]!.box, 4);
    });

    test('lessons keep best stars, latest day, most attempts', () {
      final a = LanguageBackup(lessons: {'l1': lesson('l1', 3, 10, 2)});
      final b = LanguageBackup(
        lessons: {'l1': lesson('l1', 2, 12, 5), 'l2': lesson('l2', 1, 9, 1)},
      );
      final m = LanguageBackup.merge(a, b);
      expect(m.lessons['l1']!.stars, 3);
      expect(m.lessons['l1']!.completedDay, 12);
      expect(m.lessons['l1']!.attempts, 5);
      expect(m.lessons.keys, {'l1', 'l2'});
    });

    test('days take the larger counters, freezes are united', () {
      DayLog d(int s, int l) =>
          DayLog(day: 5, seconds: s, lessons: l, reviews: 0);
      final a = ProgressBackup(days: {5: d(300, 1)}, freezes: {3});
      final b = ProgressBackup(days: {5: d(200, 2)}, freezes: {4});
      final m = ProgressBackup.merge(a, b);
      expect(m.days[5]!.seconds, 300);
      expect(m.days[5]!.lessons, 2);
      expect(m.freezes, {3, 4});
    });

    test('this device keeps its level; the cloud only fills gaps', () {
      final local = const ProgressBackup(levels: {'zh': 1});
      final cloud = const ProgressBackup(levels: {'zh': 3, 'de': 2});
      final m = ProgressBackup.merge(local, cloud);
      expect(m.levels, {'zh': 1, 'de': 2});
    });
  });

  test('documents round-trip and compare equal when data is equal', () {
    final b = ProgressBackup(
      languages: {
        'zh': LanguageBackup(
          words: {7: word(7), 3: word(3)},
          lessons: {'hsk1-1': lesson('hsk1-1', 3, 9, 1)},
          characters: {'你': 4},
        ),
        'de': const LanguageBackup(),
      },
      days: {9: DayLog(day: 9, seconds: 400, lessons: 1, reviews: 0)},
      freezes: {8},
      levels: {'zh': 2},
    );
    final docs = b.toDocuments();
    expect(docs.keys.toSet(), {'shared', 'lang_zh'}); // empty de is skipped
    final back = ProgressBackup.fromDocuments(docs);
    expect(back.toDocuments(), docs);
    expect(back.languages['zh']!.words[7]!.dueDay, 12);
    expect(back.levels['zh'], 2);
  });

  test('sqlite repository exports and imports without losing rows', () async {
    final db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(db.close);
    final repo = SqliteProgressRepository(db);
    await repo.recordLearning('zh', 10, {1: WordOutcome.clean});
    await repo.completeLesson('zh', 'l1', 2, 10);
    await repo.recordCharacterWritten('zh', '你', 10);
    await repo.addStudy(10, seconds: 240, lessons: 1);
    await repo.addFreeze(9);

    final snapshot = await repo.exportBackup();
    expect(snapshot.languages['zh']!.words.keys, {1});
    expect(snapshot.days[10]!.seconds, 240);
    expect(snapshot.freezes, {9});

    final other = SqliteProgressRepository(
      await AppDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      ),
    );
    await other.importBackup(snapshot);
    expect((await other.wordProgress('zh')).keys, {1});
    expect((await other.lessonResults('zh'))['l1']!.stars, 2);
    expect(await other.charactersWritten('zh'), {'你': 1});
    expect(await other.totalSeconds(), 240);
    expect(await other.freezeDays(), {9});
  });

  group('account controller', () {
    late FakeCloud cloud;
    late FakeAuth auth;

    Future<({ProviderContainer container, InMemoryProgressRepository repo})>
    device() async {
      final t = await makeContainer(
        extraOverrides: [
          authServiceProvider.overrideWithValue(auth),
          cloudStoreProvider.overrideWithValue(cloud),
        ],
      );
      addTearDown(t.container.dispose);
      return (container: t.container, repo: t.repo);
    }

    setUp(() {
      cloud = FakeCloud();
      auth = FakeAuth();
    });

    test('sign-in uploads progress; a second device receives it', () async {
      final a = await device();
      await a.repo.recordLearning('zh', 10, {1: WordOutcome.clean});
      await a.repo.completeLesson('zh', 'hsk1-1', 3, 10);
      await a.repo.addStudy(10, seconds: 600, lessons: 1);
      await a.container.read(accountProvider.notifier).signIn();
      final stateA = a.container.read(accountProvider);
      expect(stateA.signedIn, isTrue);
      expect(stateA.lastSynced, isNotNull);
      expect(cloud.data['u1']!.keys, containsAll(['shared', 'lang_zh']));

      final b = await device();
      await b.repo.recordLearning('zh', 11, {2: WordOutcome.clean});
      await b.container.read(accountProvider.notifier).signIn();
      // B now has A's lesson and word, A's cloud copy has B's word.
      expect((await b.repo.lessonResults('zh')).keys, {'hsk1-1'});
      expect((await b.repo.wordProgress('zh')).keys, {1, 2});
      await a.container.read(accountProvider.notifier).sync();
      expect((await a.repo.wordProgress('zh')).keys, {1, 2});
    });

    test('a cancelled sign-in is not an error', () async {
      final a = await device();
      auth.cancelNextSignIn = true;
      await a.container.read(accountProvider.notifier).signIn();
      final s = a.container.read(accountProvider);
      expect(s.signedIn, isFalse);
      expect(s.issue, AccountIssue.none);
    });

    test('a failing sync leaves local data alone and reports it', () async {
      final a = await device();
      await a.repo.recordLearning('zh', 10, {1: WordOutcome.clean});
      await a.container.read(accountProvider.notifier).signIn();
      cloud.failing = true;
      await a.container.read(accountProvider.notifier).sync();
      expect(a.container.read(accountProvider).issue, AccountIssue.syncFailed);
      expect((await a.repo.wordProgress('zh')).keys, {1});
    });

    test('resetting a language also clears its cloud copy', () async {
      final a = await device();
      await a.repo.recordLearning('zh', 10, {1: WordOutcome.clean});
      await a.container.read(accountProvider.notifier).signIn();
      expect(cloud.data['u1']!.containsKey('lang_zh'), isTrue);
      await a.container.read(progressProvider.future);
      await a.container.read(progressProvider.notifier).resetLanguage();
      await Future<void>.delayed(Duration.zero);
      expect(cloud.data['u1']!.containsKey('lang_zh'), isFalse);
      // Syncing again must not bring it back.
      await a.container.read(accountProvider.notifier).sync();
      expect(cloud.data['u1']!.containsKey('lang_zh'), isFalse);
    });

    test(
      'deleting the account asks to sign in again, then removes data',
      () async {
        final a = await device();
        await a.repo.recordLearning('zh', 10, {1: WordOutcome.clean});
        await a.container.read(accountProvider.notifier).signIn();
        auth.needsRecentLoginOnce = true;
        final ok = await a.container
            .read(accountProvider.notifier)
            .deleteAccount();
        expect(ok, isTrue);
        expect(auth.reauthCalls, 1);
        expect(cloud.data.containsKey('u1'), isFalse);
        expect(a.container.read(accountProvider).signedIn, isFalse);
        // Progress on the device stays.
        expect((await a.repo.wordProgress('zh')).keys, {1});
      },
    );

    test('signing out keeps progress on the device', () async {
      final a = await device();
      await a.repo.recordLearning('zh', 10, {1: WordOutcome.clean});
      await a.container.read(accountProvider.notifier).signIn();
      await a.container.read(accountProvider.notifier).signOut();
      expect(a.container.read(accountProvider).signedIn, isFalse);
      expect((await a.repo.wordProgress('zh')).keys, {1});
    });
  });
}
