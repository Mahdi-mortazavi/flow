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

  DayTask copyWith({bool? done}) => DayTask(
    taskId: taskId,
    title: title,
    done: done ?? this.done,
    sort: sort,
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

/// A habit anchored to an existing routine (implementation intention).
/// Bad habits carry their long-term cost and a one-tap replacement behavior.
class Habit {
  final String id;
  final String title;
  final String cue;
  final String created; // dayKey
  final bool isBad;
  final String badCost;
  final String replacement;
  final int? reminderMinutes; // minutes since midnight, null = no reminder
  final Map<String, String> logs; // dayKey -> done | slip | resisted

  const Habit({
    required this.id,
    required this.title,
    required this.cue,
    required this.created,
    required this.isBad,
    required this.badCost,
    required this.replacement,
    required this.reminderMinutes,
    required this.logs,
  });

  String? statusOn(String dayKey) => logs[dayKey];
  bool doneOn(String dayKey) => logs[dayKey] == 'done';
}

/// The official, guilt-free fun block.
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
