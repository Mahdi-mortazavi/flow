import 'dart:convert';

/// A task in the pool the morning wizard picks from.
class BacklogItem {
  final String id;
  final String title;
  const BacklogItem({required this.id, required this.title});
}

/// One of today's (max 3) chosen tasks.
class DayTask {
  final String taskId;
  final String title;
  final bool done;
  final int sort;
  const DayTask({
    required this.taskId,
    required this.title,
    required this.done,
    required this.sort,
  });

  DayTask copyWith({bool? done}) =>
      DayTask(taskId: taskId, title: title, done: done ?? this.done, sort: sort);
}

/// The full state of one day: plan, boulder, prediction, evening review.
class DayPlan {
  final String dayKey;
  final bool planned;
  final String? boulderId;
  final int? prediction;
  final List<DayTask> tasks;
  final bool closed;
  final bool? outcome;
  final List<String> whys;
  final String note;

  const DayPlan({
    required this.dayKey,
    required this.planned,
    required this.boulderId,
    required this.prediction,
    required this.tasks,
    required this.closed,
    required this.outcome,
    required this.whys,
    required this.note,
  });

  factory DayPlan.empty(String dayKey) => DayPlan(
        dayKey: dayKey,
        planned: false,
        boulderId: null,
        prediction: null,
        tasks: const [],
        closed: false,
        outcome: null,
        whys: const [],
        note: '',
      );

  DayTask? get boulder {
    for (final t in tasks) {
      if (t.taskId == boulderId) return t;
    }
    return null;
  }

  List<DayTask> get others =>
      tasks.where((t) => t.taskId != boulderId).toList();

  bool get boulderDone => boulder?.done ?? false;
}

enum ThoughtCategory {
  idea('idea', 'ایده'),
  worry('worry', 'نگرانی'),
  sideTask('side_task', 'کار فرعی');

  final String db;
  final String label;
  const ThoughtCategory(this.db, this.label);

  static ThoughtCategory fromDb(String v) =>
      values.firstWhere((c) => c.db == v, orElse: () => ThoughtCategory.idea);
}

class Thought {
  final String id;
  final String text;
  final ThoughtCategory category;
  final DateTime createdAt;
  const Thought({
    required this.id,
    required this.text,
    required this.category,
    required this.createdAt,
  });
}

/// Serialized into shared_preferences while a focus session is running,
/// so the timer survives process death (endAt is a wall-clock timestamp).
class ActiveFocus {
  final String sessionId;
  final String? taskId;
  final String title;
  final int totalSec;
  final int endAtMs;
  final bool paused;
  final int pausedLeftSec;

  const ActiveFocus({
    required this.sessionId,
    required this.taskId,
    required this.title,
    required this.totalSec,
    required this.endAtMs,
    required this.paused,
    required this.pausedLeftSec,
  });

  int remainingSec() {
    if (paused) return pausedLeftSec;
    final left = (endAtMs - DateTime.now().millisecondsSinceEpoch) / 1000;
    return left.ceil().clamp(0, totalSec);
  }

  ActiveFocus copyWith({
    int? totalSec,
    int? endAtMs,
    bool? paused,
    int? pausedLeftSec,
  }) =>
      ActiveFocus(
        sessionId: sessionId,
        taskId: taskId,
        title: title,
        totalSec: totalSec ?? this.totalSec,
        endAtMs: endAtMs ?? this.endAtMs,
        paused: paused ?? this.paused,
        pausedLeftSec: pausedLeftSec ?? this.pausedLeftSec,
      );

  String toJson() => jsonEncode({
        'sessionId': sessionId,
        'taskId': taskId,
        'title': title,
        'totalSec': totalSec,
        'endAtMs': endAtMs,
        'paused': paused,
        'pausedLeftSec': pausedLeftSec,
      });

  static ActiveFocus? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return ActiveFocus(
        sessionId: m['sessionId'] as String,
        taskId: m['taskId'] as String?,
        title: m['title'] as String,
        totalSec: m['totalSec'] as int,
        endAtMs: m['endAtMs'] as int,
        paused: m['paused'] as bool,
        pausedLeftSec: m['pausedLeftSec'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}
