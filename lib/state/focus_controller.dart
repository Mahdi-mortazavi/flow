import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/fa.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../services/notifications.dart';
import 'providers.dart';

const _prefsKey = 'active_focus_v1';

/// Snapshot the UI renders every tick.
class FocusView {
  final ActiveFocus focus;
  final int remainingSec;
  final bool finished;
  const FocusView(this.focus, this.remainingSec, this.finished);

  double get progress =>
      focus.totalSec == 0 ? 0 : 1 - remainingSec / focus.totalSec;
  String get clock => faClock(remainingSec);
}

/// Wall-clock based focus timer. The single source of truth is [ActiveFocus]
/// persisted in shared_preferences (endAt timestamp), so backgrounding or
/// killing the app never corrupts the session; the OS alarm scheduled in
/// [Notifications] covers the end signal while the app is away.
class FocusController extends Notifier<FocusView?> {
  Timer? _ticker;
  Repo get _repo => ref.read(repoProvider);

  @override
  FocusView? build() {
    ref.onDispose(_stopTicker);
    return null;
  }

  /// Restores a persisted session (call once at startup). Returns true if a
  /// session was restored (running or already finished-while-away).
  Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final focus = ActiveFocus.fromJson(prefs.getString(_prefsKey));
    if (focus == null) return false;
    _publish(focus);
    if (state?.finished ?? false) {
      // Expired while the app was away: close the session row at its real end
      // time so the deep-work stats stay honest even if the user never acts
      // on the time-up sheet. A later end() just refines the outcome.
      await _repo.endFocusSession(
        sessionId: focus.sessionId,
        completed: true,
        durationSeconds: focus.totalSec,
        endedAtMs: focus.endAtMs,
      );
    } else {
      _startTicker();
    }
    return true;
  }

  Future<void> start({
    required String? taskId,
    required String title,
    int minutes = 25,
    String kind = 'task',
  }) async {
    final sessionId = await _repo.startFocusSession(
      dayKey: todayKey(),
      taskId: taskId,
      title: title,
      plannedMin: minutes,
      kind: kind,
    );
    final totalSec = minutes * 60;
    final focus = ActiveFocus(
      sessionId: sessionId,
      taskId: taskId,
      title: title,
      kind: kind,
      totalSec: totalSec,
      endAtMs: DateTime.now()
          .add(Duration(seconds: totalSec))
          .millisecondsSinceEpoch,
      paused: false,
      pausedLeftSec: totalSec,
    );
    await _persist(focus);
    await Notifications.instance.scheduleFocusEnd(
      DateTime.fromMillisecondsSinceEpoch(focus.endAtMs),
      title,
      lang: ref.read(appLanguageProvider),
    );
    _publish(focus);
    _startTicker();
  }

  Future<void> pause() async {
    final f = state?.focus;
    if (f == null || f.paused) return;
    final updated = f.copyWith(paused: true, pausedLeftSec: f.remainingSec());
    await Notifications.instance.cancelFocusEnd();
    await _persist(updated);
    _publish(updated);
  }

  Future<void> resume() async {
    final f = state?.focus;
    if (f == null || !f.paused) return;
    final updated = f.copyWith(
      paused: false,
      endAtMs: DateTime.now()
          .add(Duration(seconds: f.pausedLeftSec))
          .millisecondsSinceEpoch,
    );
    await _persist(updated);
    await Notifications.instance.scheduleFocusEnd(
      DateTime.fromMillisecondsSinceEpoch(updated.endAtMs),
      updated.title,
      lang: ref.read(appLanguageProvider),
    );
    _publish(updated);
    _startTicker();
  }

  /// «+۱۰ دقیقه» from the time-up sheet.
  Future<void> extend(int minutes) async {
    final f = state?.focus;
    if (f == null) return;
    final extraSec = minutes * 60;
    final updated = f.copyWith(
      totalSec: f.totalSec + extraSec,
      paused: false,
      endAtMs: DateTime.now()
          .add(Duration(seconds: extraSec))
          .millisecondsSinceEpoch,
    );
    await _persist(updated);
    await Notifications.instance.scheduleFocusEnd(
      DateTime.fromMillisecondsSinceEpoch(updated.endAtMs),
      updated.title,
      lang: ref.read(appLanguageProvider),
    );
    _publish(updated);
    _startTicker();
  }

  /// Ends the session and clears all persisted state.
  /// [completed] marks the session (not the task) as finished-on-purpose.
  Future<void> end({
    required bool completed,
    int? durationSeconds,
    String? interruptNote,
    String? interruptTag,
  }) async {
    final f = state?.focus;
    _stopTicker();
    await Notifications.instance.cancelFocusEnd();
    if (f != null) {
      final elapsedSec =
          durationSeconds ??
          (f.totalSec - f.remainingSec()).clamp(0, f.totalSec);
      await _repo.endFocusSession(
        sessionId: f.sessionId,
        completed: completed,
        durationSeconds: elapsedSec,
        interruptNote: interruptNote,
        interruptTag: interruptTag,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    state = null;
    // The mirror reads focus_sessions (deep-work minutes + interrupt tags),
    // which nothing else invalidates — refresh it so a just-ended session is
    // reflected immediately instead of on the next app restart.
    ref.invalidate(statsProvider);
  }

  void _publish(ActiveFocus focus) {
    final remaining = focus.remainingSec();
    state = FocusView(focus, remaining, remaining <= 0 && !focus.paused);
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final f = state?.focus;
      if (f == null) {
        _stopTicker();
        return;
      }
      if (f.paused) return;
      _publish(f);
      if (state?.finished ?? false) _stopTicker();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _persist(ActiveFocus focus) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, focus.toJson());
  }
}
