import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the on-device progress database.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _version = 1;

  /// Opens (creating if needed) the database. Pass [path] `inMemoryDatabasePath`
  /// in tests; [factory] lets tests supply sqflite_common_ffi.
  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final resolved =
        path ?? p.join(await f.getDatabasesPath(), 'lingodaily.db');
    final db = await f.openDatabase(
      resolved,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: _create,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE word_progress (
        lang TEXT NOT NULL,
        word_id INTEGER NOT NULL,
        box INTEGER NOT NULL,
        due_day INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        lapses INTEGER NOT NULL,
        last_day INTEGER NOT NULL,
        PRIMARY KEY (lang, word_id)
      )''');
    await db.execute(
      'CREATE INDEX idx_word_due ON word_progress (lang, due_day)',
    );
    await db.execute('''
      CREATE TABLE lesson_progress (
        lang TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        stars INTEGER NOT NULL,
        completed_day INTEGER NOT NULL,
        attempts INTEGER NOT NULL,
        PRIMARY KEY (lang, lesson_id)
      )''');
    await db.execute('''
      CREATE TABLE day_log (
        day INTEGER PRIMARY KEY,
        seconds INTEGER NOT NULL,
        lessons INTEGER NOT NULL,
        reviews INTEGER NOT NULL
      )''');
    await db.execute('CREATE TABLE streak_freeze (day INTEGER PRIMARY KEY)');
    await db.execute('''
      CREATE TABLE char_progress (
        lang TEXT NOT NULL,
        ch TEXT NOT NULL,
        writes INTEGER NOT NULL,
        last_day INTEGER NOT NULL,
        PRIMARY KEY (lang, ch)
      )''');
  }

  Future<void> close() => db.close();
}
