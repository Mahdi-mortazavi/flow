import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
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
              const SheetHeader('چند دقیقه تمرکز؟'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    for (final m in const [25, 50, 90]) ...[
                      Expanded(
                        child: Pill(
                          faNum(m),
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

  @override
  Widget build(BuildContext context) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _onTimeUp(view));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _attemptEarlyEnd(view);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                view.focus.isFun ? 'وقتِ آزاد' : 'تمرکز',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                  color: view.focus.isFun ? Tone.ember : Tone.ink3,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  view.focus.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: Tone.ink2,
                    height: 1.8,
                  ),
                ),
              ),
              const SizedBox(height: 38),
              RepaintBoundary(
                child: SizedBox(
                  width: 272,
                  height: 272,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RingPainter(progress: view.progress),
                        ),
                      ),
                      Text(
                        view.clock,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 62,
                          fontWeight: FontWeight.w200,
                          fontFeatures: [FontFeature.tabularFigures()],
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
                    onTap: _quickThought,
                  ),
                ],
              ),
              const Spacer(flex: 3),
              Pressable(
                onTap: () => _attemptEarlyEnd(view),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'پایان زودهنگام',
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
  Future<void> _quickThought() async {
    final controller = TextEditingController();
    final saved = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              'فکر مزاحم؟ رهایش کن اینجا',
              sub: 'ثبت می‌شود و هیچ‌جا نمی‌رود. تو برگرد به تمرکز.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GlassField(
                controller: controller,
                hint: 'بنویس و رها کن…',
                autofocus: true,
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Pill(
                'ثبت و بازگشت به تمرکز',
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
      if (mounted) showToast(context, 'ثبت شد. ذهنت آزاد است.');
    }
  }

  Future<void> _attemptEarlyEnd(FocusView view) async {
    final n = ref.read(focusProvider.notifier);
    final wasPaused = view.focus.paused;
    if (!wasPaused) await n.pause();
    if (!mounted) return;
    final (end, note) = await showConfirmSheet(
      context,
      title: 'پایان زودهنگام؟',
      sub:
          'یک خط: چه چیزی قطعش کرد؟ (الگوی قطع‌شدن‌ها بعداً خودش را نشان می‌دهد)',
      yesLabel: 'پایان',
      noLabel: 'برگرد به تمرکز',
      withInput: true,
      inputHint: 'چه چیزی قطعش کرد؟',
      emberYes: false,
    );
    if (!mounted) return;
    if (end) {
      await n.end(completed: false, interruptNote: note);
    } else if (!wasPaused) {
      await n.resume();
    }
  }

  Future<void> _onTimeUp(FocusView view) async {
    unawaited(HapticFeedback.heavyImpact());
    final focus = view.focus;
    if (focus.isFun) {
      await ref.read(focusProvider.notifier).end(completed: true);
      if (mounted) {
        showToast(context, 'وقتِ آزاد تمام شد — بدونِ گناه، برگرد.');
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
            const SheetHeader(
              'وقت تمام شد',
              sub: 'کمال‌گرایی را رها کن. هر چه ساختی را همین حالا ثبت کن.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  Pill(
                    'انجام شد',
                    style: PillStyle.ember,
                    icon: Icons.check_rounded,
                    onTap: () => Navigator.pop(ctx, 'done'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Pill(
                          '+۱۰ دقیقه',
                          onTap: () => Navigator.pop(ctx, 'extend'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Pill(
                          'هنوز نه',
                          style: PillStyle.quiet,
                          onTap: () => Navigator.pop(ctx, 'not_yet'),
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
    final n = ref.read(focusProvider.notifier);
    switch (choice) {
      case 'done':
        final taskId = focus.taskId;
        if (taskId != null) {
          await ref.read(todayProvider.notifier).setTaskDone(taskId, true);
        }
        await n.end(completed: true);
        if (mounted) showToast(context, 'ثبت شد. کار بعدی منتظر است.');
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
  _RingPainter({required this.progress});

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
      ..color = Tone.ember;
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
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
