import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fa.dart';
import '../core/l10n.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../services/notifications.dart';
import 'focus_controller.dart';

final repoProvider = Provider<Repo>((ref) => Repo());

/// Persistent app language preference (fa or en).
class AppLanguageController extends Notifier<AppLanguage> {
  static const prefKey = 'app_language';

  @override
  AppLanguage build() {
    _load();
    return AppLanguage.fa;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(prefKey);
    if (code != null) {
      final lang = AppLanguage.fromCode(code);
      if (state != lang) {
        state = lang;
      }
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, lang.code);
  }

  Future<void> toggleLanguage() async {
    final next = state == AppLanguage.fa ? AppLanguage.en : AppLanguage.fa;
    await setLanguage(next);
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageController, AppLanguage>(
      AppLanguageController.new,
    );

/// Current day key; bumped on app resume so a new day rebuilds everything.
class DayKeyController extends Notifier<String> {
  @override
  String build() => todayKey();

  /// Returns true if the day actually changed.
  bool refresh() {
    final now = todayKey();
    if (now == state) return false;
    state = now;
    return true;
  }
}

final dayKeyProvider = NotifierProvider<DayKeyController, String>(
  DayKeyController.new,
);

/// Today's plan + mutations. Every mutation writes to the DB first, then
/// reloads, so the DB stays the single source of truth.
class TodayController extends AsyncNotifier<DayPlan> {
  Repo get _repo => ref.read(repoProvider);
  String get _dayKey => ref.read(dayKeyProvider);

  @override
  Future<DayPlan> build() {
    final dayKey = ref.watch(dayKeyProvider);
    return _repo.dayPlan(dayKey);
  }

  Future<void> _reload() async {
    state = AsyncData(await _repo.dayPlan(_dayKey));
  }

  Future<void> plan({
    required List<BacklogItem> selected,
    required String boulderId,
    required int prediction,
  }) async {
    await _repo.planDay(
      dayKey: _dayKey,
      selected: selected,
      boulderId: boulderId,
      prediction: prediction,
    );
    await _reload();
    await syncDailyReminders(_repo, _dayKey);
  }

  Future<void> setTaskDone(String taskId, bool done) async {
    await _repo.setTaskDone(_dayKey, taskId, done);
    await _reload();
  }

  Future<void> renameTask(String taskId, String title) async {
    await _repo.renameTask(_dayKey, taskId, title);
    await _reload();
  }

  Future<void> removeTask(String taskId) async {
    await _repo.removeTaskFromDay(_dayKey, taskId);
    await _reload();
  }

  Future<void> closeDay({
    required List<String> whys,
    required String note,
  }) async {
    await _repo.closeDay(dayKey: _dayKey, whys: whys, note: note);
    await _reload();
    await syncDailyReminders(_repo, _dayKey);
  }

  Future<void> reload() => _reload();
}

final todayProvider = AsyncNotifierProvider<TodayController, DayPlan>(
  TodayController.new,
);

class ThoughtsController extends AsyncNotifier<List<Thought>> {
  Repo get _repo => ref.read(repoProvider);

  @override
  Future<List<Thought>> build() => _repo.thoughts();

  Future<void> _reload() async {
    state = AsyncData(await _repo.thoughts());
  }

  Future<void> add(String text, ThoughtCategory category) async {
    await _repo.addThought(text, category);
    await _reload();
  }

  Future<void> updateThought(
    String id,
    String text,
    ThoughtCategory category,
  ) async {
    await _repo.updateThought(id, text, category);
    await _reload();
  }

  Future<void> remove(String id) async {
    await _repo.deleteThought(id);
    await _reload();
  }

  /// Undo for a delete: puts the thought back exactly as it was.
  Future<void> restore(Thought t) async {
    await _repo.restoreThought(t);
    await _reload();
  }

  /// Returns true if the thought landed directly on today's list.
  Future<bool> promote(Thought t) async {
    final onToday = await _repo.promoteThought(t, ref.read(dayKeyProvider));
    await _reload();
    ref.invalidate(todayProvider);
    return onToday;
  }
}

final thoughtsProvider =
    AsyncNotifierProvider<ThoughtsController, List<Thought>>(
      ThoughtsController.new,
    );

final focusProvider = NotifierProvider<FocusController, FocusView?>(
  FocusController.new,
);

/// Habits + today's logs. Mutations write to the DB, then reload and
/// re-sync the OS reminders.
class HabitsController extends AsyncNotifier<List<Habit>> {
  Repo get _repo => ref.read(repoProvider);

  @override
  Future<List<Habit>> build() {
    ref.watch(dayKeyProvider);
    return _repo.habits();
  }

  Future<void> _reload() async {
    state = AsyncData(await _repo.habits());
  }

  Future<void> save({
    String? id,
    required String title,
    required String cue,
    required bool isBad,
    required String badCost,
    required String replacement,
    required int? reminderMinutes,
  }) async {
    if (id == null) {
      final habit = await _repo.addHabit(
        title: title,
        cue: cue,
        isBad: isBad,
        badCost: badCost,
        replacement: replacement,
        reminderMinutes: reminderMinutes,
      );
      await Notifications.instance.scheduleHabitReminder(habit);
    } else {
      await _repo.updateHabit(
        id: id,
        title: title,
        cue: cue,
        isBad: isBad,
        badCost: badCost,
        replacement: replacement,
        reminderMinutes: reminderMinutes,
      );
      final habit = (await _repo.habits()).firstWhere((h) => h.id == id);
      await Notifications.instance.scheduleHabitReminder(habit);
    }
    await _reload();
  }

  Future<void> remove(String id) async {
    await _repo.deleteHabit(id);
    await Notifications.instance.cancelHabitReminder(id);
    await _reload();
  }

  Future<void> log(String habitId, String? status) async {
    await _repo.logHabit(habitId, ref.read(dayKeyProvider), status);
    await _reload();
  }

  Future<void> reload() => _reload();
}

final habitsProvider = AsyncNotifierProvider<HabitsController, List<Habit>>(
  HabitsController.new,
);

/// The guilt-free fun block config.
class FunController extends AsyncNotifier<FunConfig?> {
  @override
  Future<FunConfig?> build() => ref.read(repoProvider).funConfig();

  Future<void> save(FunConfig fun) async {
    await ref.read(repoProvider).setFunConfig(fun);
    state = AsyncData(fun);
  }
}

final funProvider = AsyncNotifierProvider<FunController, FunConfig?>(
  FunController.new,
);

/// The mirror. Recomputed whenever today's data changes.
final statsProvider = FutureProvider<StatsData>((ref) {
  ref
    ..watch(todayProvider)
    ..watch(habitsProvider);
  return ref.read(repoProvider).stats();
});

/// Re-plans the OS-level morning/evening/weekly nudges around today's state.
/// Call after planning, closing the day, changing reminder times, or on day
/// rollover.
Future<void> syncDailyReminders(Repo repo, String dayKey) async {
  final plan = await repo.dayPlan(dayKey);
  final morning = await repo.reminderMinutes(
    'rem_morning',
    Repo.defaultMorningMin,
  );
  final evening = await repo.reminderMinutes(
    'rem_evening',
    Repo.defaultEveningMin,
  );
  await Notifications.instance.syncDailyReminders(
    plannedToday: plan.planned,
    closedToday: plan.closed,
    morningMinutes: morning,
    eveningMinutes: evening,
  );
}
