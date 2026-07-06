import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/notifications.dart';
import '../../state/providers.dart';
import '../evening/evening_sheet.dart';
import '../focus/focus_screen.dart';
import '../vault/vault_sheet.dart';
import '../widgets/glass.dart';
import '../wizard/morning_wizard.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen>
    with WidgetsBindingObserver {
  var _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(dayKeyProvider.notifier).refresh();
    }
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await Notifications.instance.requestPermissions();
    final restored = await ref.read(focusProvider.notifier).restore();
    if (!mounted) return;
    if (restored) {
      Navigator.of(context).push(FocusScreen.route());
      return;
    }
    final plan = await ref.read(todayProvider.future);
    if (!mounted) return;
    if (!plan.planned) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) openMorningWizard(context, ref);
    }
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
                  error: (e, _) => Center(
                      child: Text('$e',
                          style: TextStyle(color: Tone.ink3, fontSize: 12))),
                  data: (plan) => _TodayBody(plan: plan),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _VaultFab(
        onTap: () => openVaultSheet(context),
      ),
    );
  }
}

/// The two soft radial glows behind everything.
class _Ambient extends StatelessWidget {
  const _Ambient();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -size.height * .22,
            right: -size.width * .18,
            child: _blob(size.width * .75,
                const Color(0xFF788CBE).withValues(alpha: .10)),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        _Header(plan: plan),
        const SizedBox(height: 6),
        const _Eyebrow('تخته‌سنگِ امروز'),
        BoulderCard(plan: plan),
        if (plan.planned && plan.others.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _Eyebrow('دو کارِ دیگر'),
          for (final t in plan.others) _OtherTaskRow(plan: plan, task: t),
        ],
        if (plan.planned) ...[
          const SizedBox(height: 26),
          _EveningCta(plan: plan),
        ],
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  final DayPlan plan;
  const _Header({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(faTodayLabel(),
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Tone.ink3)),
                const SizedBox(height: 3),
                const Text('تک‌نقطه',
                    style:
                        TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          _IconBtn(
            icon: Icons.edit_rounded,
            onTap: () {
              if (plan.closed) {
                showToast(context, 'امروز بسته شده — فردا از نو');
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
      child: Text(text,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Tone.ink3,
              letterSpacing: .4)),
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
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    if (!plan.planned) {
      return GlassCard(
        radius: Tone.rCard,
        emberRing: true,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _EmberTag('یک نقطهٔ داغ'),
            const SizedBox(height: 13),
            Text(
              'امروز هنوز چیده نشده. سه کار، یک تخته‌سنگ، یک پیش‌بینی — کمتر از یک دقیقه.',
              style: TextStyle(
                  fontSize: 15.5,
                  color: Tone.ink2,
                  fontWeight: FontWeight.w500,
                  height: 1.7),
            ),
            const SizedBox(height: 17),
            Pill('چیدنِ امروز',
                style: PillStyle.ember,
                onTap: () => openMorningWizard(context, ref)),
          ],
        ),
      );
    }

    final b = plan.boulder;
    if (b == null) return const SizedBox.shrink();

    return Stack(
      children: [
        GlassCard(
          radius: Tone.rCard,
          emberRing: true,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EmberTag('تخته‌سنگ'),
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
                  Text('پیش‌بینی صبح: ${faNum(plan.prediction ?? 0)}٪',
                      style: TextStyle(fontSize: 12.5, color: Tone.ink2)),
                  if (b.done) ...[
                    const SizedBox(width: 6),
                    const Text('— انجام شد',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Tone.ember)),
                  ],
                ],
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  if (!b.done) ...[
                    Expanded(
                      child: Pill('شروع تمرکز',
                          style: PillStyle.ember,
                          icon: Icons.play_arrow_rounded,
                          onTap: () => startFocusFlow(context, ref,
                              taskId: b.taskId, title: b.title)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Pill(
                      b.done ? 'برگردان' : 'علامتِ انجام',
                      style: PillStyle.glass,
                      onTap: () => _toggleBoulder(context, ref, plan, b),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // breathing ember glow, top-start corner
        PositionedDirectional(
          top: -40,
          start: -20,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _breath.drive(
                Tween(begin: .5, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeInOut)),
              ),
              child: Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Tone.ember.withValues(alpha: b.done ? .05 : .14),
                    Tone.ember.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleBoulder(
      BuildContext context, WidgetRef ref, DayPlan plan, DayTask b) {
    final newDone = !b.done;
    ref.read(todayProvider.notifier).setTaskDone(b.taskId, newDone);
    if (newDone) {
      HapticFeedback.heavyImpact();
      showToast(context, 'تخته‌سنگ افتاد. بقیهٔ روز، پایین‌سرازیری است.');
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
          const Icon(Icons.local_fire_department_rounded,
              size: 12, color: Tone.ember),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Tone.ember)),
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
    final locked = !plan.boulderDone && !task.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Opacity(
        opacity: task.done ? .55 : (locked ? .55 : 1),
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
                        decoration:
                            task.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (locked)
                      Text('پشتِ تخته‌سنگ در صف',
                          style:
                              TextStyle(fontSize: 11.5, color: Tone.ink3)),
                  ],
                ),
              ),
              if (!task.done)
                Pressable(
                  onTap: () => _play(context, ref),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Tone.line),
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                        size: 18, color: Tone.ink2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    if (!plan.boulderDone) {
      final b = plan.boulder;
      final (goBoulder, _) = await showConfirmSheet(
        context,
        title: 'تخته‌سنگ هنوز مانده',
        sub: 'قانونِ خانه: اول سنگِ بزرگ. مطمئنی می‌خواهی از رویش بپری؟',
        yesLabel: 'اول تخته‌سنگ',
        noLabel: 'به‌هرحال شروع کن',
      );
      if (!context.mounted) return;
      if (goBoulder && b != null) {
        startFocusFlow(context, ref, taskId: b.taskId, title: b.title);
      } else if (!goBoulder) {
        startFocusFlow(context, ref, taskId: task.taskId, title: task.title);
      }
      return;
    }
    startFocusFlow(context, ref, taskId: task.taskId, title: task.title);
  }
}

class _EveningCta extends ConsumerWidget {
  final DayPlan plan;
  const _EveningCta({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    const Text('روز بسته شد',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('فردا، دوباره از تخته‌سنگ.',
                        style: TextStyle(fontSize: 11.5, color: Tone.ink3)),
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
                const Text('مرور شب',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('۶۰ ثانیه — چک، چرا، یک خط',
                    style: TextStyle(fontSize: 11.5, color: Tone.ink3)),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, size: 20, color: Tone.ink3),
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

class _VaultFab extends StatelessWidget {
  final VoidCallback onTap;
  const _VaultFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
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
            Text('تخلیهٔ ذهن',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Tone.ink2)),
          ],
        ),
      ),
    );
  }
}
