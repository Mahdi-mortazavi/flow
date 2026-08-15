import 'dart:convert';

/// A unified domain model for all tasks (backlog, scheduled, and completed)
/// equipped with synchronization metadata for multi-device replication.
class Task {
  final String id;
  final String title;
  final String notes;
  final bool isBoulder;
  final String status; // 'pending' | 'completed'
  final String?
  scheduledDate; // dayKey e.g. '2026-08-15', null = in backlog pool
  final int? reminderTime; // minutes since midnight, null = no reminder
  final int activeOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.isBoulder = false,
    this.status = 'pending',
    this.scheduledDate,
    this.reminderTime,
    this.activeOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isDeleted => deletedAt != null;

  Task copyWith({
    String? title,
    String? notes,
    bool? isBoulder,
    String? status,
    String? scheduledDate,
    int? reminderTime,
    int? activeOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => Task(
    id: id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    isBoulder: isBoulder ?? this.isBoulder,
    status: status ?? this.status,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    reminderTime: reminderTime ?? this.reminderTime,
    activeOrder: activeOrder ?? this.activeOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}

/// A lightweight adapter representing a task in the pool the morning wizard picks from.
class BacklogItem {
  final String id;
  final String title;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const BacklogItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory BacklogItem.fromTask(Task t) => BacklogItem(
    id: t.id,
    title: t.title,
    notes: t.notes,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    deletedAt: t.deletedAt,
  );
}

/// Returns maximum tasks allowed based on non-punitive active (closed) days progression:
/// 0..14 active days -> 3 tasks (1 Boulder + 2 secondary)
/// 15..29 active days -> 4 tasks (1 Boulder + 2 secondary + 1 Pebble)
/// 30+ active days -> 5 tasks (1 Boulder + 2 secondary + 2 Pebbles) [HARD CAP]
int maxTasksForActiveDays(int activeDays) {
  if (activeDays >= 30) return 5;
  if (activeDays >= 15) return 4;
  return 3;
}

/// One of today's chosen tasks.
class DayTask {
  final String taskId;
  final String title;
  final bool done;
  final int sort;
  final String notes;
  final bool isBoulder;
  final int? reminderTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DayTask({
    required this.taskId,
    required this.title,
    required this.done,
    required this.sort,
    this.notes = '',
    this.isBoulder = false,
    this.reminderTime,
    this.createdAt,
    this.updatedAt,
  });

  factory DayTask.fromTask(Task t) => DayTask(
    taskId: t.id,
    title: t.title,
    done: t.isCompleted,
    sort: t.activeOrder,
    notes: t.notes,
    isBoulder: t.isBoulder,
    reminderTime: t.reminderTime,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  );

  DayTask copyWith({
    bool? done,
    String? title,
    int? sort,
    String? notes,
    bool? isBoulder,
    int? reminderTime,
  }) => DayTask(
    taskId: taskId,
    title: title ?? this.title,
    done: done ?? this.done,
    sort: sort ?? this.sort,
    notes: notes ?? this.notes,
    isBoulder: isBoulder ?? this.isBoulder,
    reminderTime: reminderTime ?? this.reminderTime,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
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
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

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
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
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
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Thought({
    required this.id,
    required this.text,
    required this.category,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
}

/// A habit anchored to an existing routine with sync and recovery tracking.
class Habit {
  final String id;
  final String title;
  final String cue;
  final String created; // dayKey
  final String frequency; // 'daily'
  final int recoveryCount;
  final bool isBad;
  final String badCost;
  final String replacement;
  final int? reminderMinutes; // minutes since midnight, null = no reminder
  final Map<String, String> logs; // dayKey -> done | slip | resisted
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Habit({
    required this.id,
    required this.title,
    required this.cue,
    required this.created,
    this.frequency = 'daily',
    this.recoveryCount = 0,
    required this.isBad,
    required this.badCost,
    required this.replacement,
    required this.reminderMinutes,
    required this.logs,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  String? statusOn(String dayKey) => logs[dayKey];
  bool doneOn(String dayKey) => logs[dayKey] == 'done';
  bool get isDeleted => deletedAt != null;
}

/// Domain model for Guilt-Free Play / leisure sessions.
class Leisure {
  final String id;
  final String title;
  final int durationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Leisure({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  FunConfig toFunConfig() => FunConfig(title: title, minutes: durationMinutes);
}

/// The official, guilt-free fun block config adapter.
class FunConfig {
  final String title;
  final int minutes;
  const FunConfig({required this.title, required this.minutes});

  String toJson() => jsonEncode({'title': title, 'minutes': minutes});

  static FunConfig? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return FunConfig(
        title: m['title'] as String,
        minutes: m['minutes'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The one-tap taxonomy for what broke a focus session. Order = display order.
enum InterruptTag {
  phone('phone', '📱', 'موبایل'),
  people('people', '👥', 'آدم‌ها'),
  tired('tired', '😴', 'خستگی'),
  thought('thought', '💭', 'فکر مزاحم'),
  other('other', '✍️', 'دیگر');

  final String db;
  final String emoji;
  final String label;
  const InterruptTag(this.db, this.emoji, this.label);

  static InterruptTag? fromDb(String? v) {
    if (v == null) return null;
    for (final t in values) {
      if (t.db == v) return t;
    }
    return null;
  }
}

/// Domain model for a focus timer session with sync timestamps.
class FocusSession {
  final String id;
  final String? taskId;
  final int durationSeconds;
  final DateTime? completedAt;
  final String dayKey;
  final String title;
  final int plannedMin;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool completed;
  final String? interruptNote;
  final InterruptTag? interruptTag;
  final String kind; // task | fun
  final DateTime createdAt;
  final DateTime updatedAt;

  const FocusSession({
    required this.id,
    this.taskId,
    this.durationSeconds = 0,
    this.completedAt,
    required this.dayKey,
    required this.title,
    required this.plannedMin,
    required this.startedAt,
    this.endedAt,
    this.completed = false,
    this.interruptNote,
    this.interruptTag,
    this.kind = 'task',
    required this.createdAt,
    required this.updatedAt,
  });
}

/// One closed night in the mirror.
class NightRow {
  final String dayKey;
  final int prediction;
  final bool outcome;
  const NightRow({
    required this.dayKey,
    required this.prediction,
    required this.outcome,
  });
}

/// Everything the mirror (stats screen) shows, computed in one pass.
class StatsData {
  final int closedCount;
  final int? winRate; // % of closed days where the boulder fell
  final int? avgPrediction;
  final int? gap; // avgPrediction - winRate (optimism when positive)
  final int? recoveryRate; // % of habit misses followed by a done next day
  final List<NightRow> lastNights;
  final List<int> focusMinutesLast7; // [0]=6 days ago ... [6]=today
  final List<String> recentInterrupts;
  final Map<InterruptTag, int> interruptCounts; // ranked pattern, last 30d
  final int? goldenHour; // start hour of the highest-energy 3h bucket
  final bool reviewDue;

  const StatsData({
    required this.closedCount,
    required this.winRate,
    required this.avgPrediction,
    required this.gap,
    required this.recoveryRate,
    required this.lastNights,
    required this.focusMinutesLast7,
    required this.recentInterrupts,
    required this.interruptCounts,
    required this.goldenHour,
    required this.reviewDue,
  });

  int get focusMinutesWeek => focusMinutesLast7.fold(0, (sum, m) => sum + m);

  /// Optimism hints are only meaningful with enough closed nights; below this
  /// a single unlucky day would scream "you're 90 points optimistic".
  static const optimismMinNights = 5;
  bool get optimismReliable => closedCount >= optimismMinNights;
}

/// Serialized into shared_preferences while a focus session is running,
/// so the timer survives process death (endAt is a wall-clock timestamp).
class ActiveFocus {
  final String sessionId;
  final String? taskId;
  final String title;
  final String kind; // task | fun
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
    this.kind = 'task',
  });

  bool get isFun => kind == 'fun';

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
  }) => ActiveFocus(
    sessionId: sessionId,
    taskId: taskId,
    title: title,
    kind: kind,
    totalSec: totalSec ?? this.totalSec,
    endAtMs: endAtMs ?? this.endAtMs,
    paused: paused ?? this.paused,
    pausedLeftSec: pausedLeftSec ?? this.pausedLeftSec,
  );

  String toJson() => jsonEncode({
    'sessionId': sessionId,
    'taskId': taskId,
    'title': title,
    'kind': kind,
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
        kind: (m['kind'] as String?) ?? 'task',
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
