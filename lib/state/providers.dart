import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/fa.dart';
import '../data/models.dart';
import '../data/repo.dart';
import 'focus_controller.dart';

final repoProvider = Provider<Repo>((ref) => Repo());

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
  }

  Future<void> setTaskDone(String taskId, bool done) async {
    await _repo.setTaskDone(_dayKey, taskId, done);
    await _reload();
  }

  Future<void> closeDay({
    required List<String> whys,
    required String note,
  }) async {
    await _repo.closeDay(dayKey: _dayKey, whys: whys, note: note);
    await _reload();
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
