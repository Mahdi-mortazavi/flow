import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../state/focus_controller.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Entry point: pick a duration, then start the session and open the arena.
/// Pass [fixedMinutes] (e.g. the fun block) to skip the duration sheet.
Future<void> startFocusFlow(
  BuildContext context,
  WidgetRef ref, {
  required String? taskId,
  required String title,
  String kind = 'task',
  int? fixedMinutes,
}) async {
  final lang = ref.read(appLanguageProvider);
  final minutes =
      fixedMinutes ??
      await showGlassSheet<int>(
        context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                lang == AppLanguage.fa
                    ? 'چند دقیقه تمرکز؟'
                    : 'How many minutes of focus?',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    for (final m in const [25, 50, 90]) ...[
                      Expanded(
                        child: Pill(
                          L10n.fmtNum(m, lang),
                          onTap: () => Navigator.pop(ctx, m),
                        ),
                      ),
                      if (m != 90) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  if (minutes == null || !context.mounted) return;
  await ref
      .read(focusProvider.notifier)
      .start(taskId: taskId, title: title, minutes: minutes, kind: kind);
  if (!context.mounted) return;
  unawaited(HapticFeedback.mediumImpact());
  unawaited(Navigator.of(context).push(FocusScreen.route()));
}

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
    pageBuilder: (_, __, ___) => const FocusScreen(),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 500),
  );

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  var _timeUpShown = false;
  var _exactAlarms = true;

  @override
  void initState() {
    super.initState();
    Notifications.instance.exactAlarmsAllowed().then((ok) {
      if (mounted && !ok) setState(() => _exactAlarms = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accentProvider);
    final lang = ref.watch(appLanguageProvider);
    final view = ref.watch(focusProvider);

    // Session cleared (ended elsewhere) → leave the arena.
    if (view == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(backgroundColor: Colors.black, body: SizedBox());
    }

    if (view.finished && !_timeUpShown) {
      _timeUpShown = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _onTimeUp(view, lang),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _attemptEarlyEnd(view, lang);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (view.focus.isFun ? Tone.accent : Tone.ink).withValues(
                    alpha: .08,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Tone.line),
                ),
                child: Text(
                  view.focus.isFun
                      ? (lang == AppLanguage.fa ? 'وقتِ آزاد' : 'Free Time')
                      : (lang == AppLanguage.fa
                            ? 'جلسه تمرکز'
                            : 'Focus Session'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                    color: view.focus.isFun ? Tone.accent : Tone.ink2,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              RepaintBoundary(
                child: SizedBox(
                  width: 284,
                  height: 284,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: view.progress,
                            color: Tone.accent,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              view.clock,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w200,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              view.focus.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Tone.ink2,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundBtn(
                    icon: view.focus.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    onTap: () {
                      final n = ref.read(focusProvider.notifier);
                      view.focus.paused ? n.resume() : n.pause();
                      HapticFeedback.selectionClick();
                    },
                  ),
                  const SizedBox(width: 12),
                  _RoundBtn(
                    icon: Icons.psychology_outlined,
                    onTap: () => _quickThought(lang),
                  ),
                ],
              ),
              if (!_exactAlarms) ...[
                const SizedBox(height: 16),
                Text(
                  lang == AppLanguage.fa
                      ? 'اجازهٔ زنگ دقیق داده نشده — زنگ پایان ممکن است کمی دیر برسد.'
                      : 'Exact alarms not granted — end alarm may arrive slightly late.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: Tone.ink3),
                ),
              ],
              const Spacer(flex: 3),
              Pressable(
                onTap: () => _attemptEarlyEnd(view, lang),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    lang == AppLanguage.fa ? 'پایان زودهنگام' : 'End Early',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Tone.ink3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  /// Zeigarnik valve: capture an intruding thought without leaving focus.
  Future<void> _quickThought(AppLanguage lang) async {
    final controller = TextEditingController();
    final saved = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              lang == AppLanguage.fa
                  ? 'فکر مزاحم؟ رهایش کن اینجا'
                  : 'Intruding thought? Drop it here',
              sub: lang == AppLanguage.fa
                  ? 'ثبت می‌شود و هیچ‌جا نمی‌رود. تو برگرد به تمرکز.'
                  : 'Saved securely. Now return to focus.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GlassField(
                controller: controller,
                hint: lang == AppLanguage.fa
                    ? 'بنویس و رها کن…'
                    : 'Type and release...',
                autofocus: true,
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Pill(
                lang == AppLanguage.fa
                    ? 'ثبت و بازگشت به تمرکز'
                    : 'Save & Return to Focus',
                style: PillStyle.ember,
                onTap: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (saved == true && text.isNotEmpty) {
      await ref.read(thoughtsProvider.notifier).add(text, ThoughtCategory.idea);
      if (mounted) {
        showToast(
          context,
          lang == AppLanguage.fa
              ? 'ثبت شد. ذهنت آزاد است.'
              : 'Saved. Your mind is clear.',
        );
      }
    }
  }

  Future<void> _attemptEarlyEnd(FocusView view, AppLanguage lang) async {
    final n = ref.read(focusProvider.notifier);
    final focus = view.focus;
    final wasPaused = focus.paused;
    if (!wasPaused) await n.pause();
    if (!mounted) return;

    if (focus.isFun) {
      final end = await showGlassSheet<bool>(
        context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                lang == AppLanguage.fa ? 'پایان وقت آزاد' : 'End Free Time',
                sub: lang == AppLanguage.fa
                    ? 'پایان زودهنگام تفریح و بازگشت به روال روز'
                    : 'End leisure block early and return to your day',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  children: [
                    Pill(
                      lang == AppLanguage.fa ? 'پایان و خروج' : 'End & Exit',
                      style: PillStyle.ember,
                      onTap: () => Navigator.pop(ctx, true),
                    ),
                    const SizedBox(height: 10),
                    Pill(
                      lang == AppLanguage.fa ? 'ادامه تفریح' : 'Resume Leisure',
                      style: PillStyle.quiet,
                      onTap: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (end == true) {
        await n.end(completed: true);
      } else {
        if (!wasPaused) await n.resume();
      }
      return;
    }

    final action = await showGlassSheet<String>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              lang == AppLanguage.fa
                  ? 'پایان زودهنگام تمرکز'
                  : 'End Focus Early',
              sub: lang == AppLanguage.fa
                  ? 'کار زودتر تمام شد یا متوقف شد؟'
                  : 'Did you finish early or get interrupted?',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  Pill(
                    L10n.markTaskCompleted(lang),
                    style: PillStyle.ember,
                    icon: Icons.check_circle_rounded,
                    onTap: () => Navigator.pop(ctx, 'done'),
                  ),
                  const SizedBox(height: 10),
                  Pill(
                    lang == AppLanguage.fa
                        ? 'ثبت وقفه و پایان'
                        : 'Log Interruption & End',
                    icon: Icons.pause_circle_outline_rounded,
                    onTap: () => Navigator.pop(ctx, 'interrupt'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Pill(
                          L10n.logFocusKeepPending(lang),
                          style: PillStyle.quiet,
                          onTap: () => Navigator.pop(ctx, 'keep_pending'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Pill(
                          lang == AppLanguage.fa
                              ? 'ادامه تمرکز'
                              : 'Resume Focus',
                          style: PillStyle.quiet,
                          onTap: () => Navigator.pop(ctx, 'resume'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == null || action == 'resume') {
      if (!wasPaused) await n.resume();
      return;
    }

    if (action == 'done') {
      final taskId = focus.taskId;
      if (taskId != null) {
        await ref.read(todayProvider.notifier).setTaskDone(taskId, true);
      }
      await n.end(completed: true);
      if (mounted) {
        showToast(context, L10n.taskCompletedToast(lang));
      }
      return;
    }

    if (action == 'keep_pending') {
      await n.end(completed: true);
      if (mounted) {
        showToast(context, L10n.focusLoggedKeepPendingToast(lang));
      }
      return;
    }

    if (action == 'interrupt') {
      final result = await _showInterruptSheet(lang);
      if (!mounted) return;
      if (result == null) {
        if (!wasPaused) await n.resume();
        return;
      }
      await n.end(
        completed: false,
        interruptTag: result.$1.db,
        interruptNote: result.$2,
      );
    }
  }

  /// One-tap interrupt taxonomy — the friction of typing was why the pattern
  /// stayed empty. A tag is enough; the note is optional.
  Future<(InterruptTag, String?)?> _showInterruptSheet(AppLanguage lang) {
    return showGlassSheet<(InterruptTag, String?)>(
      context,
      builder: (ctx) {
        final noteController = TextEditingController();
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                lang == AppLanguage.fa
                    ? 'چه چیزی قطعش کرد؟'
                    : 'What interrupted it?',
                sub: lang == AppLanguage.fa
                    ? 'یک ضربه کافی است — الگویش هفتگی خودش را نشان می‌دهد.'
                    : 'One tap is enough — weekly patterns will reveal themselves.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in InterruptTag.values)
                      Pressable(
                        onTap: () => Navigator.pop(ctx, (
                          tag,
                          noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        )),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Tone.line),
                          ),
                          child: Text(
                            '${tag.emoji}  ${_localizedTagLabel(tag, lang)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: GlassField(
                  controller: noteController,
                  hint: lang == AppLanguage.fa
                      ? 'یک خط، اگر خواستی (اختیاری)…'
                      : 'One line, if you wish (optional)...',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Pill(
                  lang == AppLanguage.fa ? 'برگرد به تمرکز' : 'Return to Focus',
                  style: PillStyle.quiet,
                  onTap: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _localizedTagLabel(InterruptTag tag, AppLanguage lang) {
    if (lang == AppLanguage.fa) return tag.label;
    return switch (tag) {
      InterruptTag.phone => 'Phone / Call',
      InterruptTag.people => 'People / Interruption',
      InterruptTag.tired => 'Fatigue / Low Energy',
      InterruptTag.thought => 'Intruding Thought',
      InterruptTag.other => 'Other',
    };
  }

  Future<void> _onTimeUp(FocusView view, AppLanguage lang) async {
    unawaited(HapticFeedback.heavyImpact());
    final focus = view.focus;
    if (focus.isFun) {
      await ref.read(focusProvider.notifier).end(completed: true);
      if (mounted) {
        showToast(
          context,
          lang == AppLanguage.fa
              ? 'وقتِ آزاد تمام شد — بدونِ گناه، برگرد.'
              : 'Free time is up — guilt-free, return now.',
        );
      }
      return;
    }
    final choice = await showGlassSheet<String>(
      context,
      isDismissible: false,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              L10n.focusSessionCompleteTitle(lang),
              sub: L10n.focusSessionCompleteSub(focus.title, lang),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  Pill(
                    L10n.markTaskCompleted(lang),
                    style: PillStyle.ember,
                    icon: Icons.check_circle_rounded,
                    onTap: () => Navigator.pop(ctx, 'done'),
                  ),
                  const SizedBox(height: 10),
                  Pill(
                    L10n.logFocusKeepPending(lang),
                    icon: Icons.timer_outlined,
                    onTap: () => Navigator.pop(ctx, 'keep_pending'),
                  ),
                  const SizedBox(height: 10),
                  Pill(
                    lang == AppLanguage.fa
                        ? '+۱۰ دقیقه ادامه'
                        : '+10 Min Continue',
                    style: PillStyle.quiet,
                    icon: Icons.more_time_rounded,
                    onTap: () => Navigator.pop(ctx, 'extend'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final n = ref.read(focusProvider.notifier);
    switch (choice) {
      case 'done':
        final taskId = focus.taskId;
        if (taskId != null) {
          await ref.read(todayProvider.notifier).setTaskDone(taskId, true);
        }
        await n.end(completed: true);
        if (mounted) {
          showToast(context, L10n.taskCompletedToast(lang));
        }
      case 'keep_pending':
        await n.end(completed: true);
        if (mounted) {
          showToast(context, L10n.focusLoggedKeepPendingToast(lang));
        }
      case 'extend':
        _timeUpShown = false;
        await n.extend(10);
      case _:
        await n.end(completed: true);
    }
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Tone.glassA, Tone.glassB],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Tone.line),
        ),
        child: Icon(icon, size: 22, color: Tone.ink),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: .07);
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Remaining portion of the ring, shrinking clockwise from 12 o'clock.
    final sweep = 2 * math.pi * (1 - progress);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
