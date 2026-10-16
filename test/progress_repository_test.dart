import 'package:flutter_test/flutter_test.dart';
import 'package:lingodaily/data/app_database.dart';
import 'package:lingodaily/data/progress_models.dart';
import 'package:lingodaily/data/progress_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late SqliteProgressRepository repo;

  setUp(() async {
    db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repo = SqliteProgressRepository(db);
  });

  tearDown(() => db.close());

  test('records learning and reviews per language', () async {
    await repo.recordLearning('zh', 10, {
      1: WordOutcome.clean,
      2: WordOutcome.shaky,
    });
    await repo.recordLearning('ja', 10, {1: WordOutcome.clean});
    var zh = await repo.wordProgress('zh');
    expect(zh[1]!.box, 1);
    expect(zh[2]!.box, 0);
    expect((await repo.wordProgress('ja')).length, 1);

    await repo.recordReviews('zh', 11, {1: true, 2: true});
    zh = await repo.wordProgress('zh');
    expect(zh[1]!.box, 2);
    expect(zh[2]!.isLearned, isTrue);
  });

  test('keeps the best star count and counts attempts', () async {
    await repo.completeLesson('zh', 'l1', 3, 10);
    await repo.completeLesson('zh', 'l1', 1, 11);
    final r = (await repo.lessonResults('zh'))['l1']!;
    expect(r.stars, 3);
    expect(r.attempts, 2);
  });

  test('accumulates study time per day and finds practice days', () async {
    await repo.addStudy(10, seconds: 300, lessons: 1);
    await repo.addStudy(10, seconds: 120, reviews: 1);
    await repo.addStudy(11, seconds: 60);
    final today = await repo.dayLog(10);
    expect(today.seconds, 420);
    expect(today.lessons, 1);
    expect(today.reviews, 1);
    expect((await repo.dayLog(99)).seconds, 0);
    expect(await repo.practiceDays(), {10, 11});
    expect(await repo.totalSeconds(), 480);
    expect((await repo.logsBetween(10, 11)).length, 2);
  });

  test('streak freezes and character counts persist', () async {
    await repo.addFreeze(9);
    await repo.addFreeze(9);
    expect(await repo.freezeDays(), {9});
    await repo.recordCharacterWritten('zh', '学', 10);
    await repo.recordCharacterWritten('zh', '学', 11);
    expect((await repo.charactersWritten('zh'))['学'], 2);
  });

  test('reset clears one language but keeps the time log', () async {
    await repo.recordLearning('zh', 10, {1: WordOutcome.clean});
    await repo.addStudy(10, seconds: 60);
    await repo.resetLanguage('zh');
    expect(await repo.wordProgress('zh'), isEmpty);
    expect(await repo.totalSeconds(), 60);
    await repo.resetEverything();
    expect(await repo.totalSeconds(), 0);
  });
}
