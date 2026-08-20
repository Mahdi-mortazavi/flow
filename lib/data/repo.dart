import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/fa.dart';
import 'database.dart';
import 'models.dart';

const _uuid = Uuid();

class Repo {
  Future<Database> get _db => AppDatabase.instance.db;

  // ---------- tasks & backlog (domain: tasks) ----------

  Future<List<BacklogItem>> backlog() async {
    final d = await _db;
    final rows = await d.query(
      'tasks',
      where: "status = 'pending' AND deleted_at IS NULL",
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (r) => BacklogItem(
            id: r['id'] as String,
            title: r['title'] as String,
            notes: (r['notes'] as String?) ?? '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (r['created_at'] as int?) ?? 0,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              (r['updated_at'] as int?) ?? 0,
            ),
            deletedAt: r['deleted_at'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(r['deleted_at'] as int),
          ),
        )
        .toList();
  }

  Future<BacklogItem> addBacklog(String title, {String notes = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final item = BacklogItem(
      id: id,
      title: title,
      notes: notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    final d = await _db;
    await d.insert('tasks', {
      'id': id,
      'title': title,
      'notes': notes,
      'is_boulder': 0,
      'status': 'pending',
      'scheduled_date': null,
      'reminder_time': null,
      'active_order': 0,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
    return item;
  }

  Future<void> deleteBacklog(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.update(
      'tasks',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- day plan ----------

  Future<DayPlan> dayPlan(String dayKey) async {
    final d = await _db;
    final dayRows = await d.query(
      'days',
      where: 'day_key = ? AND deleted_at IS NULL',
      whereArgs: [dayKey],
    );
    final taskRows = await d.query(
      'tasks',
      where: 'scheduled_date = ? AND deleted_at IS NULL',
      whereArgs: [dayKey],
      orderBy: 'active_order ASC',
    );
    final tasks = taskRows
        .map(
          (r) => DayTask(
            taskId: r['id'] as String,
            title: r['title'] as String,
            done: (r['status'] as String) == 'completed',
            sort: (r['active_order'] as int?) ?? 0,
            notes: (r['notes'] as String?) ?? '',
            isBoulder: (r['is_boulder'] as int?) == 1,
            reminderTime: r['reminder_time'] as int?,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (r['created_at'] as int?) ?? 0,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              (r['updated_at'] as int?) ?? 0,
            ),
          ),
        )
        .toList();

    if (dayRows.isEmpty) return DayPlan.empty(dayKey);
    final row = dayRows.first;
    return DayPlan(
      dayKey: dayKey,
      planned: (row['planned'] as int) == 1,
      boulderId: row['boulder_id'] as String?,
      prediction: row['prediction'] as int?,
      tasks: tasks,
      closed: row['closed_at'] != null,
      outcome: row['outcome'] == null ? null : (row['outcome'] as int) == 1,
      whys: (jsonDecode((row['whys'] as String?) ?? '[]') as List)
          .cast<String>(),
      note: (row['note'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at'] as int?) ?? 0,
      ),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['deleted_at'] as int),
    );
  }

  /// Writes the morning wizard result. Keeps done-flags of tasks that were
  /// already on today's list (replan case).
  Future<void> planDay({
    required String dayKey,
    required List<BacklogItem> selected,
    required String boulderId,
    required int prediction,
  }) async {
    final d = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await d.transaction((tx) async {
      final selectedIds = selected.map((s) => s.id).toSet();

      // Reset any tasks previously scheduled for this day that are no longer selected
      await tx.update(
        'tasks',
        {'scheduled_date': null, 'is_boulder': 0, 'updated_at': now},
        where:
            'scheduled_date = ? AND id NOT IN (${selectedIds.map((_) => '?').join(', ')})',
        whereArgs: [dayKey, ...selectedIds],
      );

      // Assign selected tasks to today with order and boulder flag
      for (var i = 0; i < selected.length; i++) {
        final t = selected[i];
        final isBoulder = t.id == boulderId;
        final count = Sqflite.firstIntValue(
          await tx.rawQuery('SELECT COUNT(*) FROM tasks WHERE id = ?', [t.id]),
        );
        if (count != null && count > 0) {
          await tx.update(
            'tasks',
            {
              'scheduled_date': dayKey,
              'active_order': i,
              'is_boulder': isBoulder ? 1 : 0,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [t.id],
          );
        } else {
          await tx.insert('tasks', {
            'id': t.id,
            'title': t.title,
            'notes': t.notes,
            'is_boulder': isBoulder ? 1 : 0,
            'status': 'pending',
            'scheduled_date': dayKey,
            'reminder_time': null,
            'active_order': i,
            'created_at': now,
            'updated_at': now,
            'deleted_at': null,
          });
        }
      }

      await tx.insert('days', {
        'day_key': dayKey,
        'planned': 1,
        'boulder_id': boulderId,
        'prediction': prediction,
        'whys': '[]',
        'note': '',
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> setTaskDone(String dayKey, String taskId, bool done) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.update(
      'tasks',
      {'status': done ? 'completed' : 'pending', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Renames a task everywhere its title is stored.
  Future<void> renameTask(String dayKey, String taskId, String title) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.update(
      'tasks',
      {'title': title, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Updates or clears reminder_time on a task.
  Future<void> updateTaskReminder(String taskId, int? reminderMinutes) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.update(
      'tasks',
      {'reminder_time': reminderMinutes, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Retrieves a task by id.
  Future<Task?> getTask(String taskId) async {
    final d = await _db;
    final rows = await d.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Task(
      id: r['id'] as String,
      title: r['title'] as String,
      notes: (r['notes'] as String?) ?? '',
      isBoulder: (r['is_boulder'] as int?) == 1,
      status: (r['status'] as String?) ?? 'pending',
      scheduledDate: r['scheduled_date'] as String?,
      reminderTime: r['reminder_time'] as int?,
      activeOrder: (r['active_order'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (r['created_at'] as int?) ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (r['updated_at'] as int?) ?? 0,
      ),
      deletedAt: r['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r['deleted_at'] as int),
    );
  }

  /// Removes a task from today's plan. If it was the boulder, the next task inherits the crown.
  Future<void> removeTaskFromDay(String dayKey, String taskId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.transaction((tx) async {
      await tx.update(
        'tasks',
        {
          'scheduled_date': null,
          'is_boulder': 0,
          'deleted_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [taskId],
      );

      final dayRows = await tx.query(
        'days',
        where: 'day_key = ?',
        whereArgs: [dayKey],
      );
      if (dayRows.isEmpty) return;
      if (dayRows.first['boulder_id'] != taskId) return;

      final remaining = await tx.query(
        'tasks',
        where: 'scheduled_date = ? AND deleted_at IS NULL',
        whereArgs: [dayKey],
        orderBy: 'active_order ASC',
      );
      if (remaining.isEmpty) {
        await tx.update(
          'days',
          {'boulder_id': null, 'planned': 0, 'updated_at': now},
          where: 'day_key = ?',
          whereArgs: [dayKey],
        );
      } else {
        final newBoulderId = remaining.first['id'] as String;
        await tx.update(
          'tasks',
          {'is_boulder': 1, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [newBoulderId],
        );
        await tx.update(
          'days',
          {'boulder_id': newBoulderId, 'updated_at': now},
          where: 'day_key = ?',
          whereArgs: [dayKey],
        );
      }
    });
  }

  /// Adds a task to today's list (used by "promote thought").
  Future<void> addTaskToDay(String dayKey, BacklogItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.transaction((tx) async {
      final maxSort =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT MAX(active_order) FROM tasks WHERE scheduled_date = ? AND deleted_at IS NULL',
              [dayKey],
            ),
          ) ??
          -1;

      final count = Sqflite.firstIntValue(
        await tx.rawQuery('SELECT COUNT(*) FROM tasks WHERE id = ?', [item.id]),
      );
      if (count != null && count > 0) {
        await tx.update(
          'tasks',
          {
            'scheduled_date': dayKey,
            'active_order': maxSort + 1,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [item.id],
        );
      } else {
        await tx.insert('tasks', {
          'id': item.id,
          'title': item.title,
          'notes': item.notes,
          'is_boulder': 0,
          'status': 'pending',
          'scheduled_date': dayKey,
          'reminder_time': null,
          'active_order': maxSort + 1,
          'created_at': now,
          'updated_at': now,
          'deleted_at': null,
        });
      }
    });
  }

  /// Evening review: closes the day.
  Future<void> closeDay({
    required String dayKey,
    required List<String> whys,
    required String note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.transaction((tx) async {
      final tasks = await tx.query(
        'tasks',
        where: 'scheduled_date = ? AND deleted_at IS NULL',
        whereArgs: [dayKey],
      );
      final dayRows = await tx.query(
        'days',
        where: 'day_key = ?',
        whereArgs: [dayKey],
      );
      if (dayRows.isEmpty) return;
      final boulderId = dayRows.first['boulder_id'] as String?;
      var outcome = false;
      for (final t in tasks) {
        final done = (t['status'] as String) == 'completed';
        if (t['id'] == boulderId) outcome = done;
      }
      await tx.update(
        'days',
        {
          'closed_at': now,
          'outcome': outcome ? 1 : 0,
          'whys': jsonEncode(whys),
          'note': note,
          'updated_at': now,
        },
        where: 'day_key = ?',
        whereArgs: [dayKey],
      );
    });
  }

  // ---------- thoughts (domain: thoughts) ----------

  Future<List<Thought>> thoughts() async {
    final d = await _db;
    final rows = await d.query(
      'thoughts',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (r) => Thought(
            id: r['id'] as String,
            text: r['text'] as String,
            category: ThoughtCategory.fromDb(r['category'] as String),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              r['created_at'] as int,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              (r['updated_at'] as int?) ?? 0,
            ),
            deletedAt: r['deleted_at'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(r['deleted_at'] as int),
          ),
        )
        .toList();
  }

  Future<void> addThought(String text, ThoughtCategory category) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.insert('thoughts', {
      'id': _uuid.v4(),
      'text': text,
      'category': category.db,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
  }

  Future<void> updateThought(
    String id,
    String text,
    ThoughtCategory category,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.update(
      'thoughts',
      {'text': text, 'category': category.db, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteThought(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.update(
      'thoughts',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns total count of closed/completed days (Non-Punitive Active Days).
  Future<int> activeDaysCount() async {
    final d = await _db;
    final res = await d.rawQuery(
      'SELECT COUNT(*) FROM days WHERE closed_at IS NOT NULL AND deleted_at IS NULL',
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Promote a thought: becomes a task in the backlog, and lands directly on today's
  /// list when there is room — never on a closed day.
  Future<bool> promoteThought(Thought t, String dayKey) async {
    final plan = await dayPlan(dayKey);
    final item = await addBacklog(t.text);
    await deleteThought(t.id);
    final active = await activeDaysCount();
    final maxTasks = maxTasksForActiveDays(active);
    final hasRoom =
        plan.planned && !plan.closed && plan.tasks.length < maxTasks;
    if (hasRoom) await addTaskToDay(dayKey, item);
    return hasRoom;
  }

  /// Puts a deleted thought back exactly as it was (undo).
  Future<void> restoreThought(Thought t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.insert('thoughts', {
      'id': t.id,
      'text': t.text,
      'category': t.category.db,
      'created_at': t.createdAt.millisecondsSinceEpoch,
      'updated_at': now,
      'deleted_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- focus sessions (domain: focus_sessions) ----------

  Future<String> startFocusSession({
    required String dayKey,
    required String? taskId,
    required String title,
    required int plannedMin,
    String kind = 'task',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.insert('focus_sessions', {
      'id': id,
      'task_id': taskId,
      'duration_seconds': 0,
      'completed_at': null,
      'day_key': dayKey,
      'title': title,
      'planned_min': plannedMin,
      'started_at': now,
      'ended_at': null,
      'completed': 0,
      'kind': kind,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> endFocusSession({
    required String sessionId,
    required bool completed,
    int? durationSeconds,
    String? interruptNote,
    String? interruptTag,
    int? endedAtMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final endedAt = endedAtMs ?? now;
    final d = await _db;
    final rows = await d.query(
      'focus_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    int durationSec = durationSeconds ?? 0;
    if (durationSeconds == null && rows.isNotEmpty) {
      final plannedMin = (rows.first['planned_min'] as int?) ?? 25;
      final startedAt = (rows.first['started_at'] as int?) ?? now;
      final wallSec = ((endedAt - startedAt) / 1000).round();
      // Clamp wall-clock elapsed time to planned duration so pauses / backgrounding don't inflate stats
      durationSec = wallSec.clamp(0, plannedMin * 60);
    }

    await d.update(
      'focus_sessions',
      {
        'ended_at': endedAt,
        'duration_seconds': durationSec,
        'completed_at': completed ? endedAt : null,
        'completed': completed ? 1 : 0,
        if (interruptNote != null) 'interrupt_note': interruptNote,
        if (interruptTag != null) 'interrupt_tag': interruptTag,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ---------- habits (domain: habits) ----------

  Future<List<Habit>> habits() async {
    final d = await _db;
    final rows = await d.query(
      'habits',
      where: 'deleted_at IS NULL',
      orderBy: 'sort ASC, created ASC',
    );
    final logRows = await d.query('habit_logs', where: 'deleted_at IS NULL');
    final logs = <String, Map<String, String>>{};
    for (final r in logRows) {
      (logs[r['habit_id'] as String] ??= {})[r['day_key'] as String] =
          r['status'] as String;
    }
    return rows
        .map(
          (r) => Habit(
            id: r['id'] as String,
            title: r['title'] as String,
            cue: (r['cue'] as String?) ?? '',
            created: r['created'] as String,
            frequency: (r['frequency'] as String?) ?? 'daily',
            recoveryCount: (r['recovery_count'] as int?) ?? 0,
            isBad: (r['is_bad'] as int) == 1,
            badCost: (r['bad_cost'] as String?) ?? '',
            replacement: (r['replacement'] as String?) ?? '',
            reminderMinutes: r['reminder_minutes'] as int?,
            logs: logs[r['id'] as String] ?? const {},
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (r['created_at'] as int?) ?? 0,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              (r['updated_at'] as int?) ?? 0,
            ),
            deletedAt: r['deleted_at'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(r['deleted_at'] as int),
          ),
        )
        .toList();
  }

  Future<Habit> addHabit({
    required String title,
    required String cue,
    required bool isBad,
    required String badCost,
    required String replacement,
    required int? reminderMinutes,
    String frequency = 'daily',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    final maxSort =
        Sqflite.firstIntValue(
          await d.rawQuery(
            'SELECT MAX(sort) FROM habits WHERE deleted_at IS NULL',
          ),
        ) ??
        -1;
    final habit = Habit(
      id: _uuid.v4(),
      title: title,
      cue: cue,
      created: todayKey(),
      frequency: frequency,
      isBad: isBad,
      badCost: badCost,
      replacement: replacement,
      reminderMinutes: reminderMinutes,
      logs: const {},
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    await d.insert('habits', {
      'id': habit.id,
      'title': title,
      'cue': cue,
      'created': habit.created,
      'frequency': frequency,
      'recovery_count': 0,
      'is_bad': isBad ? 1 : 0,
      'bad_cost': badCost,
      'replacement': replacement,
      'reminder_minutes': reminderMinutes,
      'sort': maxSort + 1,
      'created_at': now,
      'updated_at': now,
      'deleted_at': null,
    });
    return habit;
  }

  Future<void> updateHabit({
    required String id,
    required String title,
    required String cue,
    required bool isBad,
    required String badCost,
    required String replacement,
    required int? reminderMinutes,
    String frequency = 'daily',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.update(
      'habits',
      {
        'title': title,
        'cue': cue,
        'frequency': frequency,
        'is_bad': isBad ? 1 : 0,
        'bad_cost': badCost,
        'replacement': replacement,
        'reminder_minutes': reminderMinutes,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteHabit(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.update(
      'habits',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await d.update(
      'habit_logs',
      {'deleted_at': now, 'updated_at': now},
      where: 'habit_id = ?',
      whereArgs: [id],
    );
  }

  /// Records today's status for a habit; pass null to clear it.
  Future<void> logHabit(String habitId, String dayKey, String? status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    if (status == null) {
      await d.update(
        'habit_logs',
        {'deleted_at': now, 'updated_at': now},
        where: 'habit_id = ? AND day_key = ?',
        whereArgs: [habitId, dayKey],
      );
    } else {
      await d.insert('habit_logs', {
        'habit_id': habitId,
        'day_key': dayKey,
        'status': status,
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ---------- leisure / fun (domain: leisure) ----------

  Future<FunConfig?> funConfig() async {
    final d = await _db;
    final rows = await d.query(
      'leisure',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final r = rows.first;
      return FunConfig(
        title: r['title'] as String,
        minutes: (r['duration_minutes'] as int?) ?? 30,
      );
    }
    return FunConfig.fromJson(await getSetting('fun'));
  }

  Future<void> setFunConfig(FunConfig fun) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    final existing = await d.query(
      'leisure',
      where: 'deleted_at IS NULL',
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await d.update(
        'leisure',
        {
          'title': fun.title,
          'duration_minutes': fun.minutes,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await d.insert('leisure', {
        'id': _uuid.v4(),
        'title': fun.title,
        'duration_minutes': fun.minutes,
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      });
    }
    await setSetting('fun', fun.toJson());
  }

  // ---------- settings ----------

  Future<String?> getSetting(String key) async {
    final d = await _db;
    final rows = await d.query('settings', where: 'k = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['v'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.insert('settings', {
      'k': key,
      'v': value,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- energy checks ----------

  Future<void> addEnergyCheck(int level) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.insert('energy_checks', {
      'id': _uuid.v4(),
      'day_key': todayKey(),
      'hour': DateTime.now().hour,
      'level': level,
      'created_at': now,
      'updated_at': now,
    });
  }

  // ---------- zero-based review ----------

  Future<void> markReviewDone() => setSetting('last_review', todayKey());

  // ---------- daily reminders ----------

  static const defaultMorningMin = 8 * 60 + 30;
  static const defaultEveningMin = 21 * 60 + 30;

  Future<int?> reminderMinutes(String key, int fallback) async {
    final raw = await getSetting(key);
    if (raw == null) return fallback;
    if (raw == 'off') return null;
    return int.tryParse(raw) ?? fallback;
  }

  Future<void> setReminderMinutes(String key, int? minutes) =>
      setSetting(key, minutes == null ? 'off' : '$minutes');

  // ---------- backup / restore ----------

  static const _exportTables = [
    'tasks',
    'days',
    'habits',
    'habit_logs',
    'leisure',
    'focus_sessions',
    'thoughts',
    'energy_checks',
    'settings',
  ];

  /// Full snapshot of every domain table as portable JSON.
  Future<String> exportJson() async {
    final d = await _db;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final t in _exportTables) {
      tables[t] = await d.query(t);
    }
    return jsonEncode({
      'app': 'taknoghte',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    });
  }

  /// Restores local data from JSON backup with backward compatibility.
  Future<void> importJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('not json');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'taknoghte' ||
        decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException('not a taknoghte backup');
    }
    final tables = decoded['tables'] as Map<String, dynamic>;
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = await _db;
    await d.transaction((tx) async {
      for (final t in _exportTables) {
        await tx.delete(t);
        final rows = tables[t];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is Map) {
            await tx.insert(
              t,
              row.cast<String, Object?>(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      // Backward compatibility: If older v1 backup contains backlog or day_tasks
      if (tables.containsKey('backlog') && tables['tasks'] == null) {
        final backlogRows = tables['backlog'];
        if (backlogRows is List) {
          for (final row in backlogRows) {
            if (row is Map) {
              await tx.insert('tasks', {
                'id': row['id'],
                'title': row['title'],
                'notes': '',
                'is_boulder': 0,
                'status': 'pending',
                'scheduled_date': null,
                'reminder_time': null,
                'active_order': 0,
                'created_at': row['created_at'] ?? now,
                'updated_at': row['created_at'] ?? now,
                'deleted_at': null,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          }
        }
      }

      if (tables.containsKey('day_tasks') && tables['tasks'] == null) {
        final dayTaskRows = tables['day_tasks'];
        if (dayTaskRows is List) {
          for (final row in dayTaskRows) {
            if (row is Map) {
              await tx.insert('tasks', {
                'id': row['task_id'],
                'title': row['title'],
                'notes': '',
                'is_boulder': 0,
                'status': (row['done'] == 1) ? 'completed' : 'pending',
                'scheduled_date': row['day_key'],
                'reminder_time': null,
                'active_order': row['sort'] ?? 0,
                'created_at': now,
                'updated_at': now,
                'deleted_at': null,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      }
    });
  }

  // ---------- stats (the mirror) ----------

  Future<StatsData> stats() async {
    final d = await _db;
    final today = todayKey();

    // Closed nights with a prediction.
    final closed = await d.query(
      'days',
      where:
          'closed_at IS NOT NULL AND prediction IS NOT NULL AND deleted_at IS NULL',
      orderBy: 'day_key DESC',
    );
    final closedCount = closed.length;
    int? winRate;
    int? avgPrediction;
    int? gap;
    if (closedCount > 0) {
      final wins = closed.where((r) => r['outcome'] == 1).length;
      winRate = (wins / closedCount * 100).round();
      avgPrediction =
          (closed.fold<int>(0, (s, r) => s + (r['prediction'] as int)) /
                  closedCount)
              .round();
      gap = avgPrediction - winRate;
    }
    final lastNights = closed
        .take(7)
        .map(
          (r) => NightRow(
            dayKey: r['day_key'] as String,
            prediction: r['prediction'] as int,
            outcome: r['outcome'] == 1,
          ),
        )
        .toList();

    // Habit recovery: a missed day followed by a done day (last 45 days).
    final allHabits = await habits();
    var misses = 0;
    var recoveries = 0;
    for (final h in allHabits.where((h) => !h.isBad)) {
      var key = h.created.compareTo(shiftDayKey(today, -45)) > 0
          ? h.created
          : shiftDayKey(today, -45);
      while (key.compareTo(today) < 0) {
        if (!h.doneOn(key)) {
          misses++;
          if (h.doneOn(shiftDayKey(key, 1))) recoveries++;
        }
        key = shiftDayKey(key, 1);
      }
    }
    final recoveryRate = misses > 0
        ? (recoveries / misses * 100).round()
        : null;

    // Deep-work minutes per day, last 7 days.
    final weekStart = shiftDayKey(today, -6);
    final sessions = await d.query(
      'focus_sessions',
      where: "ended_at IS NOT NULL AND kind = 'task' AND day_key >= ?",
      whereArgs: [weekStart],
    );
    final focusMinutes = List<int>.filled(7, 0);
    for (final s in sessions) {
      final idx =
          6 -
          DateTime.parse(
            today,
          ).difference(DateTime.parse(s['day_key'] as String)).inDays;
      if (idx < 0 || idx > 6) continue;

      int sec = (s['duration_seconds'] as int?) ?? 0;
      if (sec <= 0) {
        final startedAt = s['started_at'] as int?;
        final endedAt = s['ended_at'] as int?;
        final plannedMin = (s['planned_min'] as int?) ?? 25;
        if (startedAt != null && endedAt != null) {
          final wallSec = ((endedAt - startedAt) / 1000).round();
          sec = wallSec.clamp(0, plannedMin * 60);
        } else {
          sec = plannedMin * 60;
        }
      }
      focusMinutes[idx] += (sec / 60).round().clamp(0, 24 * 60);
    }

    // Interrupt patterns: tag counts over the last 30 days
    final tagRows = await d.query(
      'focus_sessions',
      columns: ['interrupt_tag'],
      where: "interrupt_tag IS NOT NULL AND day_key >= ?",
      whereArgs: [shiftDayKey(today, -30)],
    );
    final interruptCounts = <InterruptTag, int>{};
    for (final r in tagRows) {
      final tag = InterruptTag.fromDb(r['interrupt_tag'] as String?);
      if (tag != null) {
        interruptCounts[tag] = (interruptCounts[tag] ?? 0) + 1;
      }
    }
    final interrupts = await d.query(
      'focus_sessions',
      where: "interrupt_note IS NOT NULL AND interrupt_note != ''",
      orderBy: 'started_at DESC',
      limit: 5,
    );

    // Golden hour: the 3-hour bucket with the highest average energy.
    final checks = await d.query(
      'energy_checks',
      where: 'day_key >= ?',
      whereArgs: [shiftDayKey(today, -30)],
    );
    int? goldenHour;
    if (checks.length >= 6) {
      final sums = List<int>.filled(8, 0);
      final counts = List<int>.filled(8, 0);
      for (final c in checks) {
        final bucket = (c['hour'] as int) ~/ 3;
        sums[bucket] += c['level'] as int;
        counts[bucket]++;
      }
      var best = -1.0;
      for (var i = 0; i < 8; i++) {
        if (counts[i] == 0) continue;
        final avg = sums[i] / counts[i];
        if (avg > best) {
          best = avg;
          goldenHour = i * 3;
        }
      }
    }

    // Zero-based review cadence: after 6 closed nights, then weekly.
    final lastReview = await getSetting('last_review');
    final reviewDue =
        (lastReview == null && closedCount >= 6) ||
        (lastReview != null &&
            DateTime.parse(
                  today,
                ).difference(DateTime.parse(lastReview)).inDays >=
                7);

    return StatsData(
      closedCount: closedCount,
      winRate: winRate,
      avgPrediction: avgPrediction,
      gap: gap,
      recoveryRate: recoveryRate,
      lastNights: lastNights,
      focusMinutesLast7: focusMinutes,
      recentInterrupts: interrupts
          .map((r) => r['interrupt_note'] as String)
          .toList(),
      interruptCounts: interruptCounts,
      goldenHour: goldenHour,
      reviewDue: reviewDue,
    );
  }
}
