import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  /// Overridable so parallel test isolates don't share one file.
  static String fileName = 'taknoghte.db';

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final database = await openDatabase(
      p.join(dir, fileName),
      version: 4,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createAll,
      onUpgrade: upgrade,
    );
    _db = database;
    return database;
  }

  Future<void> _createAll(Database d, int version) async {
    // 1. Domain: Tasks (unified backlog and scheduled day tasks with sync metadata)
    await d.execute('''
      CREATE TABLE tasks(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        is_boulder INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        scheduled_date TEXT,
        reminder_time INTEGER,
        active_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_scheduled ON tasks(scheduled_date)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_deleted ON tasks(deleted_at)',
    );

    // 2. Domain: Days (Planning, Boulder, Prediction, Evening Review)
    await d.execute('''
      CREATE TABLE days(
        day_key TEXT PRIMARY KEY,
        planned INTEGER NOT NULL DEFAULT 0,
        boulder_id TEXT,
        prediction INTEGER,
        closed_at INTEGER,
        outcome INTEGER,
        whys TEXT NOT NULL DEFAULT '[]',
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');

    // 3. Domain: Thoughts (Brain Vault with sync metadata)
    await d.execute('''
      CREATE TABLE thoughts(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        category TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');

    // 4. Domain: Focus Sessions (Wall-clock focus arena with duration & sync metadata)
    await d.execute('''
      CREATE TABLE focus_sessions(
        id TEXT PRIMARY KEY,
        task_id TEXT,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        day_key TEXT NOT NULL,
        title TEXT NOT NULL,
        planned_min INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        completed INTEGER NOT NULL DEFAULT 0,
        interrupt_note TEXT,
        interrupt_tag TEXT,
        kind TEXT NOT NULL DEFAULT 'task',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_focus_day ON focus_sessions(day_key)',
    );

    // 5. Domain: Habits & Habit Logs (Habit engine with sync metadata & recovery stats)
    await d.execute('''
      CREATE TABLE habits(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        cue TEXT NOT NULL DEFAULT '',
        created TEXT NOT NULL,
        frequency TEXT NOT NULL DEFAULT 'daily',
        recovery_count INTEGER NOT NULL DEFAULT 0,
        is_bad INTEGER NOT NULL DEFAULT 0,
        bad_cost TEXT NOT NULL DEFAULT '',
        replacement TEXT NOT NULL DEFAULT '',
        reminder_minutes INTEGER,
        sort INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await d.execute('''
      CREATE TABLE habit_logs(
        habit_id TEXT NOT NULL,
        day_key TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        PRIMARY KEY(habit_id, day_key)
      )
    ''');
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_logs_day ON habit_logs(day_key)',
    );

    // 6. Domain: Leisure (Guilt-Free Play block with sync metadata)
    await d.execute('''
      CREATE TABLE leisure(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL DEFAULT 30,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');

    // 7. Energy Checks & Settings
    await d.execute('''
      CREATE TABLE energy_checks(
        id TEXT PRIMARY KEY,
        day_key TEXT NOT NULL,
        hour INTEGER NOT NULL,
        level INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_energy_day ON energy_checks(day_key)',
    );

    await d.execute('''
      CREATE TABLE settings(
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Legacy tables preserved for compatibility with older raw queries
    await d.execute('''
      CREATE TABLE IF NOT EXISTS backlog(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS day_tasks(
        day_key TEXT NOT NULL,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY(day_key, task_id)
      )
    ''');
  }

  Future<void> upgrade(Database d, int from, int to) async {
    if (from < 2) {
      await d.execute(
        "ALTER TABLE focus_sessions ADD COLUMN kind TEXT NOT NULL DEFAULT 'task'",
      );
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
    if (from < 3) {
      await d.execute(
        'ALTER TABLE focus_sessions ADD COLUMN interrupt_tag TEXT',
      );
      await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_focus_day ON focus_sessions(day_key)',
      );
      await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_logs_day ON habit_logs(day_key)',
      );
      await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_energy_day ON energy_checks(day_key)',
      );
    }
    if (from < 4) {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Create unified tasks table
      await d.execute('''
        CREATE TABLE IF NOT EXISTS tasks(
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT '',
          is_boulder INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending',
          scheduled_date TEXT,
          reminder_time INTEGER,
          active_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        )
      ''');
      await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_scheduled ON tasks(scheduled_date)',
      );
      await d.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_deleted ON tasks(deleted_at)',
      );

      // Migrate existing backlog into tasks
      try {
        final backlogRows = await d.query('backlog');
        for (final r in backlogRows) {
          final id = r['id'] as String;
          final title = r['title'] as String;
          final createdAt = (r['created_at'] as int?) ?? now;
          await d.insert('tasks', {
            'id': id,
            'title': title,
            'notes': '',
            'is_boulder': 0,
            'status': 'pending',
            'scheduled_date': null,
            'reminder_time': null,
            'active_order': 0,
            'created_at': createdAt,
            'updated_at': createdAt,
            'deleted_at': null,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      } catch (_) {}

      // Migrate existing day_tasks into tasks
      try {
        final dayRows = await d.query('days');
        final boulderByDay = <String, String>{};
        for (final r in dayRows) {
          final k = r['day_key'] as String;
          final b = r['boulder_id'] as String?;
          if (b != null) boulderByDay[k] = b;
        }

        final dayTaskRows = await d.query('day_tasks');
        for (final r in dayTaskRows) {
          final taskId = r['task_id'] as String;
          final dayKey = r['day_key'] as String;
          final title = r['title'] as String;
          final done = (r['done'] as int?) == 1;
          final sort = (r['sort'] as int?) ?? 0;
          final isBoulder = boulderByDay[dayKey] == taskId;

          await d.insert('tasks', {
            'id': taskId,
            'title': title,
            'notes': '',
            'is_boulder': isBoulder ? 1 : 0,
            'status': done ? 'completed' : 'pending',
            'scheduled_date': dayKey,
            'reminder_time': null,
            'active_order': sort,
            'created_at': now,
            'updated_at': now,
            'deleted_at': null,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {}

      // 2. Create leisure table
      await d.execute('''
        CREATE TABLE IF NOT EXISTS leisure(
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          duration_minutes INTEGER NOT NULL DEFAULT 30,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER
        )
      ''');

      // Migrate settings 'fun' to leisure
      try {
        final funSetting = await d.query(
          'settings',
          where: 'k = ?',
          whereArgs: ['fun'],
        );
        if (funSetting.isNotEmpty) {
          final raw = funSetting.first['v'] as String;
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final title = m['title'] as String? ?? 'تفریح بدون عذاب وجدان';
          final minutes = (m['minutes'] as int?) ?? 30;
          await d.insert('leisure', {
            'id': const Uuid().v4(),
            'title': title,
            'duration_minutes': minutes,
            'created_at': now,
            'updated_at': now,
            'deleted_at': null,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      } catch (_) {}

      // 3. Add missing columns to habits table
      final habitCols = await _tableColumns(d, 'habits');
      if (!habitCols.contains('frequency')) {
        await d.execute(
          "ALTER TABLE habits ADD COLUMN frequency TEXT NOT NULL DEFAULT 'daily'",
        );
      }
      if (!habitCols.contains('recovery_count')) {
        await d.execute(
          'ALTER TABLE habits ADD COLUMN recovery_count INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!habitCols.contains('created_at')) {
        await d.execute(
          'ALTER TABLE habits ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!habitCols.contains('updated_at')) {
        await d.execute(
          'ALTER TABLE habits ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!habitCols.contains('deleted_at')) {
        await d.execute('ALTER TABLE habits ADD COLUMN deleted_at INTEGER');
      }

      // 4. Add missing columns to focus_sessions
      final focusCols = await _tableColumns(d, 'focus_sessions');
      if (!focusCols.contains('duration_seconds')) {
        await d.execute(
          'ALTER TABLE focus_sessions ADD COLUMN duration_seconds INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!focusCols.contains('completed_at')) {
        await d.execute(
          'ALTER TABLE focus_sessions ADD COLUMN completed_at INTEGER',
        );
      }
      if (!focusCols.contains('created_at')) {
        await d.execute(
          'ALTER TABLE focus_sessions ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!focusCols.contains('updated_at')) {
        await d.execute(
          'ALTER TABLE focus_sessions ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
      }

      // 5. Add sync columns to days, thoughts, habit_logs, energy_checks, settings
      final daysCols = await _tableColumns(d, 'days');
      if (!daysCols.contains('created_at')) {
        await d.execute(
          'ALTER TABLE days ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!daysCols.contains('updated_at')) {
        await d.execute(
          'ALTER TABLE days ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!daysCols.contains('deleted_at')) {
        await d.execute('ALTER TABLE days ADD COLUMN deleted_at INTEGER');
      }

      final thoughtCols = await _tableColumns(d, 'thoughts');
      if (!thoughtCols.contains('updated_at')) {
        await d.execute(
          'ALTER TABLE thoughts ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!thoughtCols.contains('deleted_at')) {
        await d.execute('ALTER TABLE thoughts ADD COLUMN deleted_at INTEGER');
      }

      final habitLogCols = await _tableColumns(d, 'habit_logs');
      if (!habitLogCols.contains('created_at')) {
        await d.execute(
          'ALTER TABLE habit_logs ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!habitLogCols.contains('updated_at')) {
        await d.execute(
          'ALTER TABLE habit_logs ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!habitLogCols.contains('deleted_at')) {
        await d.execute('ALTER TABLE habit_logs ADD COLUMN deleted_at INTEGER');
      }

      final energyCols = await _tableColumns(d, 'energy_checks');
      if (!energyCols.contains('created_at')) {
        await d.execute(
          'ALTER TABLE energy_checks ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!energyCols.contains('updated_at')) {
        await d.execute(
          'ALTER TABLE energy_checks ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
      }

      final settingCols = await _tableColumns(d, 'settings');
      if (!settingCols.contains('updated_at')) {
        await d.execute(
          'ALTER TABLE settings ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
  }

  Future<Set<String>> _tableColumns(Database d, String table) async {
    try {
      final info = await d.rawQuery('PRAGMA table_info($table)');
      return info.map((r) => r['name'] as String).toSet();
    } catch (_) {
      return {};
    }
  }
}
