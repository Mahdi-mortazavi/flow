import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taknoghte/data/database.dart';
import 'package:taknoghte/data/models.dart';
import 'package:taknoghte/data/repo.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.fileName = 'test_db_sync_migration.db';
  });

  group('Domain Separation & UUID Generation', () {
    late Repo repo;

    setUp(() async {
      repo = Repo();
      final db = await AppDatabase.instance.db;
      for (final t in [
        'tasks',
        'days',
        'thoughts',
        'focus_sessions',
        'habits',
        'habit_logs',
        'leisure',
        'energy_checks',
        'settings',
      ]) {
        await db.delete(t);
      }
    });

    test('Tasks domain uses valid UUIDs and sync timestamps', () async {
      final item = await repo.addBacklog('Task 1', notes: 'My note');
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(uuidRegex.hasMatch(item.id), true);

      final db = await AppDatabase.instance.db;
      final taskRow = (await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [item.id],
      )).single;
      expect(taskRow['title'], 'Task 1');
      expect(taskRow['notes'], 'My note');
      expect(taskRow['status'], 'pending');
      expect(taskRow['is_boulder'], 0);
      expect(taskRow['created_at'], isNotNull);
      expect(taskRow['updated_at'], isNotNull);
      expect(taskRow['deleted_at'], isNull);

      // Soft delete
      await repo.deleteBacklog(item.id);
      final updatedRow = (await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [item.id],
      )).single;
      expect(updatedRow['deleted_at'], isNotNull);
      expect(await repo.backlog(), isEmpty);
    });

    test(
      'Habits domain uses UUIDs, frequency, recovery count and sync columns',
      () async {
        final habit = await repo.addHabit(
          title: 'Morning Water',
          cue: 'Waking up',
          isBad: false,
          badCost: '',
          replacement: '',
          reminderMinutes: 480,
        );

        final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        );
        expect(uuidRegex.hasMatch(habit.id), true);

        final db = await AppDatabase.instance.db;
        final row = (await db.query(
          'habits',
          where: 'id = ?',
          whereArgs: [habit.id],
        )).single;
        expect(row['title'], 'Morning Water');
        expect(row['frequency'], 'daily');
        expect(row['recovery_count'], 0);
        expect(row['created_at'], isNotNull);
        expect(row['updated_at'], isNotNull);
        expect(row['deleted_at'], isNull);
      },
    );

    test(
      'Leisure domain stores guilt-free play config with UUID & sync columns',
      () async {
        await repo.setFunConfig(
          const FunConfig(title: 'Video Games', minutes: 45),
        );

        final fun = await repo.funConfig();
        expect(fun?.title, 'Video Games');
        expect(fun?.minutes, 45);

        final db = await AppDatabase.instance.db;
        final row = (await db.query('leisure')).single;
        expect(row['title'], 'Video Games');
        expect(row['duration_minutes'], 45);
        expect(row['created_at'], isNotNull);
        expect(row['updated_at'], isNotNull);
        expect(row['deleted_at'], isNull);
      },
    );

    test(
      'Focus sessions domain stores duration_seconds and completed_at',
      () async {
        final sessionId = await repo.startFocusSession(
          dayKey: '2026-08-15',
          taskId: null,
          title: 'Deep Coding',
          plannedMin: 30,
        );

        await repo.endFocusSession(sessionId: sessionId, completed: true);

        final db = await AppDatabase.instance.db;
        final row = (await db.query(
          'focus_sessions',
          where: 'id = ?',
          whereArgs: [sessionId],
        )).single;
        expect(row['completed'], 1);
        expect(row['completed_at'], isNotNull);
        expect(row['duration_seconds'], isNotNull);
        expect(row['created_at'], isNotNull);
        expect(row['updated_at'], isNotNull);
      },
    );
  });

  group('SQLite onUpgrade Migration from v3 to v4', () {
    test('Migrates existing backlog, day_tasks, and fun settings cleanly', () async {
      final dir = await getDatabasesPath();
      final dbPath = p.join(dir, 'test_migration_v3_to_v4.db');
      await databaseFactory.deleteDatabase(dbPath);

      // 1. Create v3 database
      final dbV3 = await openDatabase(
        dbPath,
        version: 3,
        onCreate: (d, v) async {
          await d.execute(
            'CREATE TABLE backlog(id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE days(day_key TEXT PRIMARY KEY, planned INTEGER NOT NULL DEFAULT 0, boulder_id TEXT, prediction INTEGER, closed_at INTEGER, outcome INTEGER, whys TEXT NOT NULL DEFAULT \'[]\', note TEXT NOT NULL DEFAULT \'\')',
          );
          await d.execute(
            'CREATE TABLE day_tasks(day_key TEXT NOT NULL, task_id TEXT NOT NULL, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, sort INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(day_key, task_id))',
          );
          await d.execute(
            'CREATE TABLE thoughts(id TEXT PRIMARY KEY, text TEXT NOT NULL, category TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE focus_sessions(id TEXT PRIMARY KEY, day_key TEXT NOT NULL, task_id TEXT, title TEXT NOT NULL, planned_min INTEGER NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER, completed INTEGER NOT NULL DEFAULT 0, interrupt_note TEXT, interrupt_tag TEXT, kind TEXT NOT NULL DEFAULT \'task\')',
          );
          await d.execute(
            'CREATE TABLE habits(id TEXT PRIMARY KEY, title TEXT NOT NULL, cue TEXT NOT NULL, created TEXT NOT NULL, is_bad INTEGER NOT NULL DEFAULT 0, bad_cost TEXT NOT NULL DEFAULT \'\', replacement TEXT NOT NULL DEFAULT \'\', reminder_minutes INTEGER, sort INTEGER NOT NULL DEFAULT 0)',
          );
          await d.execute(
            'CREATE TABLE habit_logs(habit_id TEXT NOT NULL, day_key TEXT NOT NULL, status TEXT NOT NULL, PRIMARY KEY(habit_id, day_key))',
          );
          await d.execute(
            'CREATE TABLE energy_checks(id TEXT PRIMARY KEY, day_key TEXT NOT NULL, hour INTEGER NOT NULL, level INTEGER NOT NULL)',
          );
          await d.execute(
            'CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT NOT NULL)',
          );
        },
      );

      // Insert v3 test data
      await dbV3.insert('backlog', {
        'id': 'legacy-task-1',
        'title': 'Legacy Backlog Task',
        'created_at': 1700000000000,
      });
      await dbV3.insert('days', {
        'day_key': '2026-08-15',
        'planned': 1,
        'boulder_id': 'legacy-boulder-1',
        'prediction': 80,
      });
      await dbV3.insert('day_tasks', {
        'day_key': '2026-08-15',
        'task_id': 'legacy-boulder-1',
        'title': 'Legacy Boulder Task',
        'done': 1,
        'sort': 0,
      });
      await dbV3.insert('settings', {
        'k': 'fun',
        'v': '{"title":"Guitar","minutes":25}',
      });
      await dbV3.close();

      // 2. Open with AppDatabase v4 schema migration
      final migratedDb = await openDatabase(
        dbPath,
        version: 4,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, v) {},
        onUpgrade: AppDatabase.instance.upgrade,
      );

      // Verify tasks table has migrated rows
      final tasks = await migratedDb.query('tasks', orderBy: 'title ASC');
      expect(tasks.length, 2);

      final backlogRow = tasks.firstWhere((t) => t['id'] == 'legacy-task-1');
      expect(backlogRow['title'], 'Legacy Backlog Task');
      expect(backlogRow['scheduled_date'], isNull);
      expect(backlogRow['status'], 'pending');

      final boulderRow = tasks.firstWhere((t) => t['id'] == 'legacy-boulder-1');
      expect(boulderRow['title'], 'Legacy Boulder Task');
      expect(boulderRow['scheduled_date'], '2026-08-15');
      expect(boulderRow['status'], 'completed');
      expect(boulderRow['is_boulder'], 1);

      // Verify leisure table has migrated row
      final leisureRows = await migratedDb.query('leisure');
      expect(leisureRows.length, 1);
      expect(leisureRows.first['title'], 'Guitar');
      expect(leisureRows.first['duration_minutes'], 25);
    });
  });
}
