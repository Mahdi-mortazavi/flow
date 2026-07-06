import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final database = await openDatabase(
      p.join(dir, 'taknoghte.db'),
      version: 2,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createAll,
      onUpgrade: _upgrade,
    );
    _db = database;
    return database;
  }

  Future<void> _createAll(Database d, int version) async {
    await d.execute('''
      CREATE TABLE backlog(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await d.execute('''
      CREATE TABLE days(
        day_key TEXT PRIMARY KEY,
        planned INTEGER NOT NULL DEFAULT 0,
        boulder_id TEXT,
        prediction INTEGER,
        closed_at INTEGER,
        outcome INTEGER,
        whys TEXT NOT NULL DEFAULT '[]',
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await d.execute('''
      CREATE TABLE day_tasks(
        day_key TEXT NOT NULL,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(day_key, task_id)
      )
    ''');
    await d.execute('''
      CREATE TABLE thoughts(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        category TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await d.execute('''
      CREATE TABLE focus_sessions(
        id TEXT PRIMARY KEY,
        day_key TEXT NOT NULL,
        task_id TEXT,
        title TEXT NOT NULL,
        planned_min INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        completed INTEGER NOT NULL DEFAULT 0,
        interrupt_note TEXT,
        kind TEXT NOT NULL DEFAULT 'task'
      )
    ''');
    await _createV2(d);
  }

  Future<void> _createV2(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS habits(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        cue TEXT NOT NULL,
        created TEXT NOT NULL,
        is_bad INTEGER NOT NULL DEFAULT 0,
        bad_cost TEXT NOT NULL DEFAULT '',
        replacement TEXT NOT NULL DEFAULT '',
        reminder_minutes INTEGER,
        sort INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS habit_logs(
        habit_id TEXT NOT NULL,
        day_key TEXT NOT NULL,
        status TEXT NOT NULL,
        PRIMARY KEY(habit_id, day_key)
      )
    ''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS energy_checks(
        id TEXT PRIMARY KEY,
        day_key TEXT NOT NULL,
        hour INTEGER NOT NULL,
        level INTEGER NOT NULL
      )
    ''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgrade(Database d, int from, int to) async {
    if (from < 2) {
      await d.execute(
        "ALTER TABLE focus_sessions ADD COLUMN kind TEXT NOT NULL DEFAULT 'task'",
      );
      await _createV2(d);
    }
  }
}
