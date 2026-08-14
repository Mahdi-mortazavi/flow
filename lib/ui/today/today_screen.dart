import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../core/fa.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../state/providers.dart';
import '../evening/evening_sheet.dart';
import '../focus/focus_screen.dart';
import '../habits/friction_sheet.dart';
import '../habits/habit_editor.dart';
import '../settings/settings_sheet.dart';
import '../stats/review_sheet.dart';
import '../stats/stats_screen.dart';
import '../vault/vault_sheet.dart';
import '../widgets/glass.dart';
import '../wizard/morning_wizard.dart';
import 'task_edit_sheet.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  var _bootstrapped = false;
  Timer? _dayWatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    // Midnight rollover while the app stays open: cheap 30s check.
    _dayWatch = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _onPossibleDayChange(),
    );
  }

  @override
  void dispose() {
    _dayWatch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onPossibleDayChange();
  }

  Future<void> _onPossibleDayChange() async {
    if (!ref.read(dayKeyProvider.notifier).refresh()) return;
    await syncDailyReminders(
      ref.read(repoProvider),
      ref.read(dayKeyProvider),
      ref.read(appLanguageProvider),
    );
    // Fresh day: open the wizard unless a focus session is running.
    final plan = await ref.read(todayProvider.future);
    if (!mounted) return;
    if (!plan.planned && ref.read(focusProvider) == null) {
      unawaited(openMorningWizard(context, ref));
    }
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await Notifications.instance.requestPermissions();
    // Wire up notification actions («انجام شد ✓» on a habit reminder).
    Notifications.instance.onHabitsChanged = () {
      if (mounted) ref.invalidate(habitsProvider);
    };
    await Notifications.instance.consumeLaunchAction();
    // Idempotent re-sync of daily habit reminders.
    final habits = await ref.read(habitsProvider.future);
    if (!mounted) return;
    final lang = ref.read(appLanguageProvider);
    await Notifications.instance.syncHabitReminders(habits, lang: lang);
    if (!mounted) return;
    await syncDailyReminders(
      ref.read(repoProvider),
      ref.read(dayKeyProvider),
      lang,
    );
    if (!mounted) return;
    final restored = await ref.read(focusProvider.notifier).restore();
    if (!mounted) return;
    if (restored) {
      unawaited(Navigator.of(context).push(FocusScreen.route()));
      return;
    }
    _setupQuickActions();
    final plan = await ref.read(todayProvider.future);
    if (!mounted) return;
    if (!plan.planned) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) unawaited(openMorningWizard(context, ref));
    }
  }

  /// Long-press the launcher icon → «ثبت فکر»: capture a thought without the
  /// full trip through the home screen. Fires on cold start too.
  void _setupQuickActions() {
    final lang = ref.read(appLanguageProvider);
    const QuickActions()
      ..initialize((type) {
        if (type == 'new_thought' && mounted) openVaultSheet(context);
      })
      ..setShortcutItems([
        ShortcutItem(
          type: 'new_thought',
          localizedTitle: lang == AppLanguage.fa
              ? 'ثبت فکر'
              : 'Capture Thought',
          icon: 'ic_stat_dot',
        ),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(todayProvider);
    return Scaffold(
      body: Stack(
        children: [
          const _Ambient(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: planAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) =>
                      ErrorCard(onRetry: () => ref.invalidate(todayProvider)),
                  data: (plan) => _TodayBody(plan: plan),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _VaultFab(onTap: () => openVaultSheet(context)),
    );
  }
}

/// The two soft radial glows behind everything.
class _Ambient extends StatelessWidget {
  const _Ambient();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -size.height * .22,
            right: -size.width * .18,
            child: _blob(
              size.width * .75,
              const Color(0xFF788CBE).withValues(alpha: .10),
            ),
          ),
          Positioned(
            bottom: -size.height * .25,
            left: -size.width * .20,
            child: _blob(size.width * .80, Tone.ember.withValues(alpha: .055)),
          ),
        ],
      ),
    );
  }

  Widget _blob(double d, Color color) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class _TodayBody extends ConsumerWidget {
  final DayPlan plan;
  const _TodayBody({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        Reveal(child: _Header(plan: plan)),
        const Reveal(order: 1, child: _ReviewBanner()),
        const SizedBox(height: 6),
        Reveal(
          order: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Eyebrow(L10n.boulderOfToday(lang)),
              BoulderCard(plan: plan),
            ],
          ),
        ),
        if (plan.planned && plan.others.isNotEmpty)
          Reveal(
            order: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 22),
                _Eyebrow(L10n.otherTasksHeader(plan.others.length, lang)),
                for (final t in plan.others) _OtherTaskRow(plan: plan, task: t),
              ],
            ),
          ),
        const SizedBox(height: 22),
        const Reveal(order: 3, child: _HabitsSection()),
        const SizedBox(height: 22),
        Reveal(
          order: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Eyebrow(L10n.guiltFreePlayBlock(lang)),
              const _FunCard(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Reveal(order: 5, child: _EnergyCard()),
        if (plan.planned)
          Reveal(
            order: 6,
            child: Column(
              children: [
                const SizedBox(height: 26),
                _EveningCta(plan: plan),
              ],
            ),
          ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  final DayPlan plan;
  const _Header({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.fmtTodayLabel(lang),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Tone.ink3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  L10n.appTitle(lang),
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _IconBtn(
            icon: Icons.tune_rounded,
            onTap: () => openSettingsSheet(context),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.bar_chart_rounded,
            onTap: () => Navigator.of(context).push(StatsScreen.route()),
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.edit_rounded,
            onTap: () {
              if (plan.closed) {
                showToast(
                  context,
                  lang == AppLanguage.fa
                      ? 'امروز بسته شده — فردا از نو'
                      : 'Today is closed — start fresh tomorrow',
                );
                return;
              }
              openMorningWizard(context, ref);
            },
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Tone.glassA, Tone.glassB],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Tone.line),
        ),
        child: Icon(icon, size: 19, color: Tone.ink2),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Tone.ink3,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

/// The one warm thing on screen.
class BoulderCard extends ConsumerStatefulWidget {
  final DayPlan plan;
  const BoulderCard({super.key, required this.plan});

  @override
  ConsumerState<BoulderCard> createState() => _BoulderCardState();
}

class _BoulderCardState extends ConsumerState<BoulderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  /// The ember only breathes while the boulder is alive — saves frames and
  /// visually mirrors "the fire went quiet" once it's done.
  void _syncBreath() {
    final active = widget.plan.planned && !(widget.plan.boulder?.done ?? false);
    if (active && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!active && _breath.isAnimating) {
      _breath.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final plan = widget.plan;
    _syncBreath();
    if (!plan.planned) {
      return GlassCard(
        radius: Tone.rCard,
        emberRing: true,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EmberTag(lang == AppLanguage.fa ? 'یک نقطهٔ داغ' : 'One Hot Spot'),
            const SizedBox(height: 13),
            Text(
              L10n.todayNotPlannedYet(lang),
              style: TextStyle(
                fontSize: 15.5,
                color: Tone.ink2,
                fontWeight: FontWeight.w500,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 17),
            Pill(
              L10n.planToday(lang),
              style: PillStyle.ember,
              onTap: () => openMorningWizard(context, ref),
            ),
          ],
        ),
      );
    }

    final b = plan.boulder;
    if (b == null) return const SizedBox.shrink();

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            openTaskEditSheet(
              context,
              ref,
              taskId: b.taskId,
              title: b.title,
              isBoulder: true,
            );
          },
          child: GlassCard(
            radius: Tone.rCard,
            emberRing: true,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            // The whole hero card is the primary action: tap → start focus.
            onTap: b.done
                ? null
                : () => unawaited(
                    startFocusFlow(
                      context,
                      ref,
                      taskId: b.taskId,
                      title: b.title,
                    ),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EmberTag(L10n.boulderTitle(lang)),
                const SizedBox(height: 13),
                Text(
                  b.title,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                    color: b.done ? Tone.ink3 : Tone.ink,
                    decoration: b.done ? TextDecoration.lineThrough : null,
                    decorationColor: Tone.ember.withValues(alpha: .5),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      lang == AppLanguage.fa
                          ? 'پیش‌بینی صبح: ${L10n.fmtNum(plan.prediction ?? 0, lang)}٪'
                          : 'Morning prediction: ${L10n.fmtNum(plan.prediction ?? 0, lang)}%',
                      style: TextStyle(fontSize: 12.5, color: Tone.ink2),
                    ),
                    if (b.done) ...[
                      const SizedBox(width: 6),
                      Text(
                        lang == AppLanguage.fa ? '— انجام شد' : '— Done',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Tone.ember,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 17),
                // Absorb stray taps around the buttons so a near-miss never
                // triggers the card's start-focus action by accident.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        if (!b.done) ...[
                          Expanded(
                            child: Pill(
                              L10n.startFocus(lang),
                              style: PillStyle.ember,
                              icon: Icons.play_arrow_rounded,
                              onTap: () => startFocusFlow(
                                context,
                                ref,
                                taskId: b.taskId,
                                title: b.title,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Pill(
                            b.done
                                ? L10n.undo(lang)
                                : (lang == AppLanguage.fa
                                      ? 'علامتِ انجام'
                                      : 'Mark Done'),
                            onTap: () =>
                                _toggleBoulder(context, ref, plan, b, lang),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // breathing ember glow, top-start corner
        PositionedDirectional(
          top: -40,
          start: -20,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _breath.drive(
                Tween(
                  begin: .5,
                  end: 1.0,
                ).chain(CurveTween(curve: Curves.easeInOut)),
              ),
              child: Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Tone.ember.withValues(alpha: b.done ? .05 : .14),
                      Tone.ember.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleBoulder(
    BuildContext context,
    WidgetRef ref,
    DayPlan plan,
    DayTask b,
    AppLanguage lang,
  ) {
    final newDone = !b.done;
    ref.read(todayProvider.notifier).setTaskDone(b.taskId, newDone);
    if (newDone) {
      HapticFeedback.heavyImpact();
      showToast(
        context,
        lang == AppLanguage.fa
            ? 'تخته‌سنگ افتاد. بقیهٔ روز، پایین‌سرازیری است.'
            : 'The Boulder has fallen! The rest of the day is downhill momentum.',
      );
    }
  }
}

class _EmberTag extends StatelessWidget {
  final String text;
  const _EmberTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Tone.emberSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Tone.ember.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 12,
            color: Tone.ember,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Tone.ember,
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherTaskRow extends ConsumerWidget {
  final DayPlan plan;
  final DayTask task;
  const _OtherTaskRow({required this.plan, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final locked = !plan.boulderDone && !task.done;
    final taskIndex = plan.tasks.indexOf(task);
    final isPebble = taskIndex >= 3;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Opacity(
        opacity: task.done ? .55 : (locked ? .55 : 1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            openTaskEditSheet(
              context,
              ref,
              taskId: task.taskId,
              title: task.title,
              isBoulder: false,
            );
          },
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                CheckCircle(
                  on: task.done,
                  onTap: () => ref
                      .read(todayProvider.notifier)
                      .setTaskDone(task.taskId, !task.done),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          color: task.done ? Tone.ink3 : Tone.ink,
                          decoration: task.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (isPebble) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Tone.emberSoft,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                L10n.pebbleTag(lang),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Tone.ember,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                L10n.pebbleHelperText(lang),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Tone.ink3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (locked)
                        Text(
                          L10n.queuedBehindBoulder(lang),
                          style: TextStyle(fontSize: 11.5, color: Tone.ink3),
                        ),
                    ],
                  ),
                ),
                if (!task.done)
                  Pressable(
                    onTap: () => _play(context, ref, lang),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: Tone.line),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: Tone.ink2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    AppLanguage lang,
  ) async {
    if (!plan.boulderDone) {
      final b = plan.boulder;
      final (goBoulder, _) = await showConfirmSheet(
        context,
        title: lang == AppLanguage.fa
            ? 'تخته‌سنگ هنوز مانده'
            : 'The Boulder remains',
        sub: lang == AppLanguage.fa
            ? 'قانونِ خانه: اول سنگِ بزرگ. مطمئنی می‌خواهی از رویش بپری؟'
            : 'Rule of the house: The Boulder comes first. Are you sure you want to skip it?',
        yesLabel: lang == AppLanguage.fa ? 'اول تخته‌سنگ' : 'Boulder First',
        noLabel: lang == AppLanguage.fa ? 'به‌هرحال شروع کن' : 'Start Anyway',
      );
      if (!context.mounted) return;
      if (goBoulder && b != null) {
        unawaited(
          startFocusFlow(context, ref, taskId: b.taskId, title: b.title),
        );
      } else if (!goBoulder) {
        unawaited(
          startFocusFlow(context, ref, taskId: task.taskId, title: task.title),
        );
      }
      return;
    }
    unawaited(
      startFocusFlow(context, ref, taskId: task.taskId, title: task.title),
    );
  }
}

class _EveningCta extends ConsumerWidget {
  final DayPlan plan;
  const _EveningCta({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    if (plan.closed) {
      return Opacity(
        opacity: .7,
        child: GlassCard(
          radius: Tone.rCard,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child: Row(
            children: [
              _moon(),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == AppLanguage.fa ? 'روز بسته شد' : 'Day Closed',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      lang == AppLanguage.fa
                          ? 'فردا، دوباره از تخته‌سنگ.'
                          : 'Tomorrow, start fresh with the Boulder.',
                      style: TextStyle(fontSize: 11.5, color: Tone.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GlassCard(
      radius: Tone.rCard,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      onTap: () => openEveningSheet(context, ref),
      child: Row(
        children: [
          _moon(),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.eveningReviewTitle(lang),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  L10n.eveningReviewSub(lang),
                  style: TextStyle(fontSize: 11.5, color: Tone.ink3),
                ),
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 20,
            color: Tone.ink3,
          ),
        ],
      ),
    );
  }

  Widget _moon() => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Tone.line),
    ),
    child: Icon(Icons.nightlight_round, size: 17, color: Tone.ink2),
  );
}

/// Weekly zero-based review nudge.
class _ReviewBanner extends ConsumerWidget {
  const _ReviewBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final due = ref.watch(statsProvider).value?.reviewDue ?? false;
    if (!due) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        onTap: () => openReviewSheet(context),
        child: Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 18,
              color: Tone.ember,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == AppLanguage.fa
                        ? 'وقتِ بازبینی مبنا-صفر است'
                        : 'Time for zero-based review',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    lang == AppLanguage.fa
                        ? 'لیستِ کوتاه، نصفِ تمرکز است — ۵ دقیقه'
                        : 'A concise list is half the focus — 5 minutes',
                    style: TextStyle(fontSize: 11, color: Tone.ink3),
                  ),
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
              color: Tone.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HABITS ====================

class _HabitsSection extends ConsumerWidget {
  const _HabitsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final habitsAsync = ref.watch(habitsProvider);
    final habits = habitsAsync.value ?? const <Habit>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  L10n.habitsTitle(lang),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Tone.ink3,
                    letterSpacing: .4,
                  ),
                ),
              ),
              Pressable(
                onTap: () => openHabitEditor(context),
                child: Text(
                  '+ ${L10n.habitTitle(lang)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Tone.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (habits.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              lang == AppLanguage.fa
                  ? 'عادت یعنی: بعد از یک رویدادِ همیشگی، یک رفتارِ کوچک.\nبا «+ عادت» اولین لنگر را بگذار.'
                  : 'A habit is: after a routine event, a tiny behavior.\nTap "+ Habit" to set your first anchor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Tone.ink3, height: 2),
            ),
          )
        else
          for (final h in habits)
            h.isBad ? _BadHabitRow(habit: h) : _GoodHabitRow(habit: h),
      ],
    );
  }
}

class _GoodHabitRow extends ConsumerWidget {
  final Habit habit;
  const _GoodHabitRow({required this.habit});

  /// Recovery-first messaging instead of a punishing streak.
  (String, Color)? _note(String today, AppLanguage lang) {
    if (habit.doneOn(today)) return null;
    final y = shiftDayKey(today, -1);
    final y2 = shiftDayKey(today, -2);
    final missedY = habit.created.compareTo(y) <= 0 && !habit.doneOn(y);
    final missedY2 = habit.created.compareTo(y2) <= 0 && !habit.doneOn(y2);
    if (missedY && missedY2) {
      return (
        lang == AppLanguage.fa
            ? 'دو روز شد — فقط نسخهٔ ۲ دقیقه‌ای را بزن'
            : 'Two days missed — just do the 2-minute version',
        Tone.warn,
      );
    }
    if (missedY) {
      return (
        lang == AppLanguage.fa
            ? 'دیروز جا ماند — امروز برگرد، زنجیره سالم می‌ماند'
            : 'Missed yesterday — return today, the chain stays healthy',
        Tone.ember,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final today = ref.watch(dayKeyProvider);
    final done = habit.doneOn(today);
    final note = _note(today, lang);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => openHabitEditor(context, habit: habit),
        child: Row(
          children: [
            CheckCircle(
              on: done,
              onTap: () => ref
                  .read(habitsProvider.notifier)
                  .log(habit.id, done ? null : 'done'),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: done ? Tone.ink3 : Tone.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    lang == AppLanguage.fa
                        ? 'بعد از ${habit.cue}'
                        : 'after ${habit.cue}',
                    style: TextStyle(fontSize: 11.5, color: Tone.ink3),
                  ),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: note.$2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (habit.reminderMinutes != null)
              Icon(
                Icons.notifications_none_rounded,
                size: 14,
                color: Tone.ink3,
              ),
          ],
        ),
      ),
    );
  }
}

class _BadHabitRow extends ConsumerWidget {
  final Habit habit;
  const _BadHabitRow({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final today = ref.watch(dayKeyProvider);
    final status = habit.statusOn(today);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => openHabitEditor(context, habit: habit),
        child: Row(
          children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Tone.warn.withValues(alpha: .10),
                border: Border.all(color: Tone.warn.withValues(alpha: .3)),
              ),
              child: Icon(
                Icons.block_rounded,
                size: 13,
                color: Tone.warn.withValues(alpha: .8),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    lang == AppLanguage.fa
                        ? 'بعد از ${habit.cue}'
                        : 'after ${habit.cue}',
                    style: TextStyle(fontSize: 11.5, color: Tone.ink3),
                  ),
                  if (status == 'resisted')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        lang == AppLanguage.fa
                            ? 'امروز مقاومت کردی ✓'
                            : 'Resisted today ✓',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Tone.ember,
                        ),
                      ),
                    )
                  else if (status == 'slip')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        lang == AppLanguage.fa
                            ? 'لغزش ثبت شد — فردا روزِ جدید است'
                            : 'Slip logged — tomorrow is a fresh day',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Tone.ink3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (status == null)
              Pressable(
                onTap: () => openFrictionSheet(context, habit),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Tone.warn.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Tone.warn.withValues(alpha: .2)),
                  ),
                  child: Text(
                    lang == AppLanguage.fa ? 'وسوسه شدم' : 'Tempted',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Tone.warn.withValues(alpha: .9),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== FUN ====================

class _FunCard extends ConsumerWidget {
  const _FunCard();

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    FunConfig? fun,
  ) async {
    final lang = ref.read(appLanguageProvider);
    final title = TextEditingController(text: fun?.title ?? '');
    final minutes = TextEditingController(text: '${fun?.minutes ?? 45}');
    final saved = await showGlassSheet<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              lang == AppLanguage.fa ? 'وقتِ آزاد' : 'Free Time',
              sub: lang == AppLanguage.fa
                  ? 'تفریح، باقی‌ماندهٔ روز نیست؛ بخشِ رسمی برنامه است. زمان‌دار و بی‌گناه.'
                  : 'Play is not leftovers; it is an official part of the plan. Timed and guilt-free.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  GlassField(
                    controller: title,
                    label: lang == AppLanguage.fa
                        ? 'چه کاری؟'
                        : 'What activity?',
                    hint: lang == AppLanguage.fa
                        ? 'مثلاً: گیم، سریال، موسیقی'
                        : 'e.g., Gaming, Shows, Music',
                  ),
                  const SizedBox(height: 12),
                  GlassField(
                    controller: minutes,
                    label: lang == AppLanguage.fa
                        ? 'چند دقیقه؟'
                        : 'How many minutes?',
                    hint: '45',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Pill(
                    L10n.save(lang),
                    style: PillStyle.ember,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final t = title.text.trim();
    final m = (int.tryParse(minutes.text) ?? 45).clamp(5, 240);
    title.dispose();
    minutes.dispose();
    if (saved != true) return;
    if (t.isEmpty) {
      if (context.mounted) {
        showToast(
          context,
          lang == AppLanguage.fa
              ? 'اسمِ تفریح را بنویس'
              : 'Enter the activity name',
        );
      }
      return;
    }
    await ref.read(funProvider.notifier).save(FunConfig(title: t, minutes: m));
  }

  /// Temptation bundling: before the boulder falls, fun is soft-locked — an
  /// honest speed-bump, not a wall. Once it's done, play runs immediately.
  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    FunConfig fun,
    bool locked,
  ) async {
    final lang = ref.read(appLanguageProvider);
    if (locked) {
      final (goBoulder, _) = await showConfirmSheet(
        context,
        title: lang == AppLanguage.fa ? 'اول تخته‌سنگ؟' : 'Boulder first?',
        sub: lang == AppLanguage.fa
            ? 'تفریح بعد از افتادنِ تخته‌سنگ، واقعاً بی‌گناه می‌شود. الان مطمئنی؟'
            : 'Play after the Boulder is truly guilt-free. Are you sure right now?',
        yesLabel: lang == AppLanguage.fa ? 'صبر می‌کنم' : 'I\'ll wait',
        noLabel: lang == AppLanguage.fa ? 'به‌هرحال شروع کن' : 'Start anyway',
      );
      if (!context.mounted || goBoulder) return;
    }
    unawaited(
      startFocusFlow(
        context,
        ref,
        taskId: null,
        title: fun.title,
        kind: 'fun',
        fixedMinutes: fun.minutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final fun = ref.watch(funProvider).value;
    final plan = ref.watch(todayProvider).value;
    final locked = (plan?.planned ?? false) && !(plan?.boulderDone ?? false);
    if (fun == null) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => _edit(context, ref, null),
        child: Row(
          children: [
            Icon(Icons.add_rounded, size: 16, color: Tone.ink3),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang == AppLanguage.fa
                    ? 'یک تفریحِ زمان‌دار تعریف کن — بدون آن، فان به وسطِ کار نشت می‌کند'
                    : 'Define a timed play block — without it, play leaks into work.',
                style: TextStyle(fontSize: 13, color: Tone.ink3, height: 1.7),
              ),
            ),
          ],
        ),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => _edit(context, ref, fun),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fun.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  locked
                      ? (lang == AppLanguage.fa
                            ? 'تخته‌سنگ بیفتد، بی‌گناه‌تر می‌شود'
                            : 'Even better once the Boulder falls')
                      : (lang == AppLanguage.fa
                            ? 'بی‌گناه. بخشِ رسمی برنامه.'
                            : 'Guilt-free. Official part of the plan.'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: locked
                        ? Tone.ember.withValues(alpha: .75)
                        : Tone.ink3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Tone.line),
            ),
            child: Text(
              lang == AppLanguage.fa
                  ? '${L10n.fmtNum(fun.minutes, lang)} دقیقه'
                  : '${L10n.fmtNum(fun.minutes, lang)} min',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Tone.ink3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: () => _play(context, ref, fun, locked),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Tone.line),
              ),
              child: Icon(
                locked ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: locked ? Tone.ember.withValues(alpha: .75) : Tone.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ENERGY ====================

class _EnergyCard extends ConsumerWidget {
  const _EnergyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    Widget chip(String label, int level) => Pressable(
      onTap: () async {
        await ref.read(repoProvider).addEnergyCheck(level);
        ref.invalidate(statsProvider);
        if (context.mounted) {
          unawaited(HapticFeedback.selectionClick());
          showToast(
            context,
            lang == AppLanguage.fa
                ? 'ثبت شد — ساعتِ طلایی‌ات کم‌کم پیدا می‌شود'
                : 'Logged — your Golden Hour pattern will emerge',
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Tone.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Tone.ink2,
          ),
        ),
      ),
    );

    // One slim row — a two-second check-in, not a form.
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 16, color: Tone.ember),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lang == AppLanguage.fa ? 'انرژی الان؟' : 'Energy right now?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Tone.ink2,
              ),
            ),
          ),
          chip(lang == AppLanguage.fa ? 'کم' : 'Low', 1),
          const SizedBox(width: 6),
          chip(lang == AppLanguage.fa ? 'متوسط' : 'Med', 2),
          const SizedBox(width: 6),
          chip(lang == AppLanguage.fa ? 'زیاد' : 'High', 3),
        ],
      ),
    );
  }
}

class _VaultFab extends ConsumerWidget {
  final VoidCallback onTap;
  const _VaultFab({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF232329), Color(0xFF141418)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Tone.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .6),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined, size: 18, color: Tone.ink2),
            const SizedBox(width: 8),
            Text(
              L10n.brainVaultTitle(lang),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Tone.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
