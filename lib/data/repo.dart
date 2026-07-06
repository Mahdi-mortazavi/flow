import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../core/fa.dart';
import 'database.dart';
import 'models.dart';

String _uid() {
  final r = Random();
  final now = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final rand = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  return '$now$rand';
}

class Repo {
  Future<Database> get _db => AppDatabase.instance.db;

  // ---------- backlog ----------

  Future<List<BacklogItem>> backlog() async {
    final rows = await (await _db).query('backlog', orderBy: 'created_at DESC');
    return rows
        .map(
          (r) =>
              BacklogItem(id: r['id'] as String, title: r['title'] as String),
        )
        .toList();
  }

  Future<BacklogItem> addBacklog(String title) async {
    final item = BacklogItem(id: _uid(), title: title);
    await (await _db).insert('backlog', {
      'id': item.id,
      'title': item.title,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return item;
  }

  Future<void> deleteBacklog(String id) async {
    await (await _db).delete('backlog', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- day plan ----------

  Future<DayPlan> dayPlan(String dayKey) async {
    final d = await _db;
    final dayRows = await d.query(
      'days',
      where: 'day_key = ?',
      whereArgs: [dayKey],
    );
    final taskRows = await d.query(
      'day_tasks',
      where: 'day_key = ?',
      whereArgs: [dayKey],
      orderBy: 'sort ASC',
    );
    final tasks = taskRows
        .map(
          (r) => DayTask(
            taskId: r['task_id'] as String,
            title: r['title'] as String,
            done: (r['done'] as int) == 1,
            sort: r['sort'] as int,
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
      whys: (jsonDecode(row['whys'] as String) as List).cast<String>(),
      note: row['note'] as String,
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
    await d.transaction((tx) async {
      final old = await tx.query(
        'day_tasks',
        where: 'day_key = ?',
        whereArgs: [dayKey],
      );
      final oldDone = {
        for (final r in old) r['task_id'] as String: (r['done'] as int) == 1,
      };
      await tx.delete('day_tasks', where: 'day_key = ?', whereArgs: [dayKey]);
      for (var i = 0; i < selected.length; i++) {
        final t = selected[i];
        await tx.insert('day_tasks', {
          'day_key': dayKey,
          'task_id': t.id,
          'title': t.title,
          'done': (oldDone[t.id] ?? false) ? 1 : 0,
          'sort': i,
        });
      }
      await tx.insert('days', {
        'day_key': dayKey,
        'planned': 1,
        'boulder_id': boulderId,
        'prediction': prediction,
        'whys': '[]',
        'note': '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> setTaskDone(String dayKey, String taskId, bool done) async {
    await (await _db).update(
      'day_tasks',
      {'done': done ? 1 : 0},
      where: 'day_key = ? AND task_id = ?',
      whereArgs: [dayKey, taskId],
    );
  }

  /// Adds a task to today's list (used by "promote thought"). Also ensures it
  /// exists in the backlog so a replan doesn't lose it.
  Future<void> addTaskToDay(String dayKey, BacklogItem item) async {
    final d = await _db;
    await d.transaction((tx) async {
      final maxSort =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT MAX(sort) FROM day_tasks WHERE day_key = ?',
              [dayKey],
            ),
          ) ??
          -1;
      await tx.insert('day_tasks', {
        'day_key': dayKey,
        'task_id': item.id,
        'title': item.title,
        'done': 0,
        'sort': maxSort + 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  /// Evening review: closes the day and removes completed tasks from the
  /// backlog for good.
  Future<void> closeDay({
    required String dayKey,
    required List<String> whys,
    required String note,
  }) async {
    final d = await _db;
    await d.transaction((tx) async {
      final tasks = await tx.query(
        'day_tasks',
        where: 'day_key = ?',
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
        final done = (t['done'] as int) == 1;
        if (t['task_id'] == boulderId) outcome = done;
        if (done) {
          await tx.delete(
            'backlog',
            where: 'id = ?',
            whereArgs: [t['task_id']],
          );
        }
      }
      await tx.update(
        'days',
        {
          'closed_at': DateTime.now().millisecondsSinceEpoch,
          'outcome': outcome ? 1 : 0,
          'whys': jsonEncode(whys),
          'note': note,
        },
        where: 'day_key = ?',
        whereArgs: [dayKey],
      );
    });
  }

  // ---------- thoughts ----------

  Future<List<Thought>> thoughts() async {
    final rows = await (await _db).query(
      'thoughts',
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
          ),
        )
        .toList();
  }

  Future<void> addThought(String text, ThoughtCategory category) async {
    await (await _db).insert('thoughts', {
      'id': _uid(),
      'text': text,
      'category': category.db,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateThought(
    String id,
    String text,
    ThoughtCategory category,
  ) async {
    await (await _db).update(
      'thoughts',
      {'text': text, 'category': category.db},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteThought(String id) async {
    await (await _db).delete('thoughts', where: 'id = ?', whereArgs: [id]);
  }

  /// Promote a thought: becomes a backlog item, and lands directly on today's
  /// list when there is room. Returns true if it made it onto today.
  Future<bool> promoteThought(Thought t, String dayKey) async {
    final plan = await dayPlan(dayKey);
    final item = await addBacklog(t.text);
    await deleteThought(t.id);
    final hasRoom = plan.planned && plan.tasks.length < 3;
    if (hasRoom) await addTaskToDay(dayKey, item);
    return hasRoom;
  }

  // ---------- focus sessions ----------

  Future<String> startFocusSession({
    required String dayKey,
    required String? taskId,
    required String title,
    required int plannedMin,
    String kind = 'task',
  }) async {
    final id = _uid();
    await (await _db).insert('focus_sessions', {
      'id': id,
      'day_key': dayKey,
      'task_id': taskId,
      'title': title,
      'planned_min': plannedMin,
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'completed': 0,
      'kind': kind,
    });
    return id;
  }

  Future<void> endFocusSession({
    required String sessionId,
    required bool completed,
    String? interruptNote,
  }) async {
    await (await _db).update(
      'focus_sessions',
      {
        'ended_at': DateTime.now().millisecondsSinceEpoch,
        'completed': completed ? 1 : 0,
        'interrupt_note': interruptNote,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ---------- habits ----------

  Future<List<Habit>> habits() async {
    final d = await _db;
    final rows = await d.query('habits', orderBy: 'sort ASC, created ASC');
    final logRows = await d.query('habit_logs');
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
            cue: r['cue'] as String,
            created: r['created'] as String,
            isBad: (r['is_bad'] as int) == 1,
            badCost: r['bad_cost'] as String,
            replacement: r['replacement'] as String,
            reminderMinutes: r['reminder_minutes'] as int?,
            logs: logs[r['id'] as String] ?? const {},
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
  }) async {
    final d = await _db;
    final maxSort =
        Sqflite.firstIntValue(
          await d.rawQuery('SELECT MAX(sort) FROM habits'),
        ) ??
        -1;
    final habit = Habit(
      id: _uid(),
      title: title,
      cue: cue,
      created: todayKey(),
      isBad: isBad,
      badCost: badCost,
      replacement: replacement,
      reminderMinutes: reminderMinutes,
      logs: const {},
    );
    await d.insert('habits', {
      'id': habit.id,
      'title': title,
      'cue': cue,
      'created': habit.created,
      'is_bad': isBad ? 1 : 0,
      'bad_cost': badCost,
      'replacement': replacement,
      'reminder_minutes': reminderMinutes,
      'sort': maxSort + 1,
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
  }) async {
    await (await _db).update(
      'habits',
      {
        'title': title,
        'cue': cue,
        'is_bad': isBad ? 1 : 0,
        'bad_cost': badCost,
        'replacement': replacement,
        'reminder_minutes': reminderMinutes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteHabit(String id) async {
    final d = await _db;
    await d.delete('habits', where: 'id = ?', whereArgs: [id]);
    await d.delete('habit_logs', where: 'habit_id = ?', whereArgs: [id]);
  }

  /// Records today's status for a habit; pass null to clear it.
  Future<void> logHabit(String habitId, String dayKey, String? status) async {
    final d = await _db;
    if (status == null) {
      await d.delete(
        'habit_logs',
        where: 'habit_id = ? AND day_key = ?',
        whereArgs: [habitId, dayKey],
      );
    } else {
      await d.insert('habit_logs', {
        'habit_id': habitId,
        'day_key': dayKey,
        'status': status,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ---------- settings / fun ----------

  Future<String?> getSetting(String key) async {
    final rows = await (await _db).query(
      'settings',
      where: 'k = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['v'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await (await _db).insert('settings', {
      'k': key,
      'v': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<FunConfig?> funConfig() async =>
      FunConfig.fromJson(await getSetting('fun'));

  Future<void> setFunConfig(FunConfig fun) => setSetting('fun', fun.toJson());

  // ---------- energy ----------

  Future<void> addEnergyCheck(int level) async {
    await (await _db).insert('energy_checks', {
      'id': _uid(),
      'day_key': todayKey(),
      'hour': DateTime.now().hour,
      'level': level,
    });
  }

  // ---------- zero-based review ----------

  Future<void> markReviewDone() => setSetting('last_review', todayKey());

  // ---------- stats (the mirror) ----------

  Future<StatsData> stats() async {
    final d = await _db;
    final today = todayKey();

    // Closed nights with a prediction.
    final closed = await d.query(
      'days',
      where: 'closed_at IS NOT NULL AND prediction IS NOT NULL',
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
      final ms = (s['ended_at'] as int) - (s['started_at'] as int);
      focusMinutes[idx] += (ms / 60000).round().clamp(0, 24 * 60);
    }

    // Interrupt patterns: most recent early-end reasons.
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
      goldenHour: goldenHour,
      reviewDue: reviewDue,
    );
  }
}
