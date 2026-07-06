import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

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
    final rows = await (await _db)
        .query('backlog', orderBy: 'created_at DESC');
    return rows
        .map((r) => BacklogItem(id: r['id'] as String, title: r['title'] as String))
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
    final dayRows =
        await d.query('days', where: 'day_key = ?', whereArgs: [dayKey]);
    final taskRows = await d.query('day_tasks',
        where: 'day_key = ?', whereArgs: [dayKey], orderBy: 'sort ASC');
    final tasks = taskRows
        .map((r) => DayTask(
              taskId: r['task_id'] as String,
              title: r['title'] as String,
              done: (r['done'] as int) == 1,
              sort: r['sort'] as int,
            ))
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
      final old = await tx.query('day_tasks',
          where: 'day_key = ?', whereArgs: [dayKey]);
      final oldDone = {
        for (final r in old)
          r['task_id'] as String: (r['done'] as int) == 1,
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
      await tx.insert(
        'days',
        {
          'day_key': dayKey,
          'planned': 1,
          'boulder_id': boulderId,
          'prediction': prediction,
          'whys': '[]',
          'note': '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> setTaskDone(String dayKey, String taskId, bool done) async {
    await (await _db).update('day_tasks', {'done': done ? 1 : 0},
        where: 'day_key = ? AND task_id = ?', whereArgs: [dayKey, taskId]);
  }

  /// Adds a task to today's list (used by "promote thought"). Also ensures it
  /// exists in the backlog so a replan doesn't lose it.
  Future<void> addTaskToDay(String dayKey, BacklogItem item) async {
    final d = await _db;
    await d.transaction((tx) async {
      final maxSort = Sqflite.firstIntValue(await tx.rawQuery(
              'SELECT MAX(sort) FROM day_tasks WHERE day_key = ?', [dayKey])) ??
          -1;
      await tx.insert(
        'day_tasks',
        {
          'day_key': dayKey,
          'task_id': item.id,
          'title': item.title,
          'done': 0,
          'sort': maxSort + 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
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
      final tasks = await tx
          .query('day_tasks', where: 'day_key = ?', whereArgs: [dayKey]);
      final dayRows =
          await tx.query('days', where: 'day_key = ?', whereArgs: [dayKey]);
      if (dayRows.isEmpty) return;
      final boulderId = dayRows.first['boulder_id'] as String?;
      var outcome = false;
      for (final t in tasks) {
        final done = (t['done'] as int) == 1;
        if (t['task_id'] == boulderId) outcome = done;
        if (done) {
          await tx.delete('backlog',
              where: 'id = ?', whereArgs: [t['task_id']]);
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
    final rows =
        await (await _db).query('thoughts', orderBy: 'created_at DESC');
    return rows
        .map((r) => Thought(
              id: r['id'] as String,
              text: r['text'] as String,
              category: ThoughtCategory.fromDb(r['category'] as String),
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            ))
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
      String id, String text, ThoughtCategory category) async {
    await (await _db).update(
        'thoughts', {'text': text, 'category': category.db},
        where: 'id = ?', whereArgs: [id]);
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
}
