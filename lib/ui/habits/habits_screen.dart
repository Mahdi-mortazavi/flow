import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fa.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';
import 'friction_sheet.dart';
import 'habit_editor.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accentProvider);
    final lang = ref.watch(appLanguageProvider);
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const _Ambient(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: habitsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) =>
                      ErrorCard(onRetry: () => ref.invalidate(habitsProvider)),
                  data: (habits) => _HabitsBody(habits: habits, lang: lang),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ambient extends ConsumerWidget {
  const _Ambient();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accentProvider);
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -size.height * .20,
            left: -size.width * .15,
            child: _blob(size.width * .75, Tone.accent.withValues(alpha: .08)),
          ),
          Positioned(
            bottom: -size.height * .25,
            right: -size.width * .20,
            child: _blob(
              size.width * .80,
              const Color(0xFF788CBE).withValues(alpha: .06),
            ),
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

class _HabitsBody extends ConsumerWidget {
  final List<Habit> habits;
  final AppLanguage lang;

  const _HabitsBody({required this.habits, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goodHabits = habits.where((h) => !h.isBad).toList();
    final badHabits = habits.where((h) => h.isBad).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        Reveal(child: _Header(lang: lang)),
        const SizedBox(height: 16),
        Reveal(
          order: 1,
          child: Pill(
            '+ ${L10n.newHabit(lang)}',
            style: PillStyle.ember,
            expanded: false,
            onTap: () => openHabitEditor(context),
          ),
        ),
        const SizedBox(height: 24),
        if (habits.isEmpty)
          Reveal(
            order: 2,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Tone.accent.withValues(alpha: .12),
                      border: Border.all(
                        color: Tone.accent.withValues(alpha: .30),
                      ),
                    ),
                    child: Icon(
                      Icons.repeat_rounded,
                      size: 26,
                      color: Tone.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    L10n.emptyHabitsTitle(lang),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    L10n.emptyHabitsSubtitle(lang),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Tone.ink3,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (goodHabits.isNotEmpty) ...[
            Reveal(
              order: 2,
              child: _SectionEyebrow(
                label: L10n.activeHabits(lang),
                count: goodHabits.length,
                lang: lang,
              ),
            ),
            const SizedBox(height: 8),
            for (final h in goodHabits)
              Reveal(
                order: 2,
                child: _HabitCard(habit: h, lang: lang),
              ),
          ],
          if (badHabits.isNotEmpty) ...[
            const SizedBox(height: 20),
            Reveal(
              order: 3,
              child: _SectionEyebrow(
                label: L10n.badHabitFriction(lang),
                count: badHabits.length,
                lang: lang,
              ),
            ),
            const SizedBox(height: 8),
            for (final h in badHabits)
              Reveal(
                order: 3,
                child: _BadHabitCard(habit: h, lang: lang),
              ),
          ],
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AppLanguage lang;
  const _Header({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.habitsTab(lang),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            L10n.habitsSubtitle(lang),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Tone.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  final String label;
  final int count;
  final AppLanguage lang;

  const _SectionEyebrow({
    required this.label,
    required this.count,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Tone.ink3,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Tone.line),
            ),
            child: Text(
              L10n.fmtNum(count, lang),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Tone.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  final Habit habit;
  final AppLanguage lang;

  const _HabitCard({required this.habit, required this.lang});

  (String, Color)? _recoveryNote(String today, AppLanguage lang) {
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
    final today = ref.watch(dayKeyProvider);
    final done = habit.doneOn(today);
    final note = _recoveryNote(today, lang);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: done ? Tone.ink3 : Tone.ink,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang == AppLanguage.fa
                        ? 'بعد از ${habit.cue}'
                        : 'after ${habit.cue}',
                    style: TextStyle(fontSize: 12, color: Tone.ink3),
                  ),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .05),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 14,
                  color: Tone.accent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BadHabitCard extends ConsumerWidget {
  final Habit habit;
  final AppLanguage lang;

  const _BadHabitCard({required this.habit, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(dayKeyProvider);
    final status = habit.statusOn(today);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () => openHabitEditor(context, habit: habit),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Tone.warn.withValues(alpha: .12),
                border: Border.all(color: Tone.warn.withValues(alpha: .35)),
              ),
              child: Icon(
                Icons.block_rounded,
                size: 15,
                color: Tone.warn.withValues(alpha: .9),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang == AppLanguage.fa
                        ? 'محرک: ${habit.cue}'
                        : 'Trigger: ${habit.cue}',
                    style: TextStyle(fontSize: 12, color: Tone.ink3),
                  ),
                  if (status == 'resisted')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        lang == AppLanguage.fa
                            ? 'امروز مقاومت کردی ✓'
                            : 'Resisted today ✓',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Tone.accent,
                        ),
                      ),
                    )
                  else if (status == 'slip')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        lang == AppLanguage.fa
                            ? 'لغزش ثبت شد — فردا از نو'
                            : 'Slip logged — start fresh tomorrow',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Tone.warn,
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
