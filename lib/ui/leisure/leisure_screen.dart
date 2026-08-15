import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../focus/focus_screen.dart';
import '../widgets/glass.dart';

class LeisureScreen extends ConsumerWidget {
  const LeisureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accentProvider);
    final lang = ref.watch(appLanguageProvider);
    final funAsync = ref.watch(funProvider);
    final plan = ref.watch(todayProvider).value;

    return Scaffold(
      body: Stack(
        children: [
          const _Ambient(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: funAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) =>
                      ErrorCard(onRetry: () => ref.invalidate(funProvider)),
                  data: (fun) => _LeisureBody(fun: fun, plan: plan, lang: lang),
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
            right: -size.width * .15,
            child: _blob(size.width * .75, Tone.ember.withValues(alpha: .08)),
          ),
          Positioned(
            bottom: -size.height * .25,
            left: -size.width * .20,
            child: _blob(size.width * .80, Tone.accent.withValues(alpha: .06)),
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

class _LeisureBody extends ConsumerWidget {
  final FunConfig? fun;
  final DayPlan? plan;
  final AppLanguage lang;

  const _LeisureBody({
    required this.fun,
    required this.plan,
    required this.lang,
  });

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
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
              lang == AppLanguage.fa ? 'تنظیم تفریح' : 'Configure Leisure',
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
                        ? 'عنوان فعالیت'
                        : 'Activity Title',
                    hint: lang == AppLanguage.fa
                        ? 'مثلاً: گیم، مطالعه آزاد، فیلم، پیاده‌روی'
                        : 'e.g., Gaming, Reading, Movies, Walk',
                  ),
                  const SizedBox(height: 12),
                  GlassField(
                    controller: minutes,
                    label: lang == AppLanguage.fa
                        ? 'مدت زمان (دقیقه)'
                        : 'Duration (Minutes)',
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
              ? 'عنوان تفریح را بنویسید'
              : 'Please enter the activity title',
        );
      }
      return;
    }
    await ref.read(funProvider.notifier).save(FunConfig(title: t, minutes: m));
  }

  Future<void> _startPlay(BuildContext context, WidgetRef ref) async {
    final activeFun =
        fun ??
        FunConfig(
          title: lang == AppLanguage.fa
              ? 'تفریح بدون عذاب وجدان'
              : 'Guilt-Free Play',
          minutes: 30,
        );
    final locked = (plan?.planned ?? false) && !(plan?.boulderDone ?? false);

    if (locked) {
      final (goBoulder, _) = await showConfirmSheet(
        context,
        title: lang == AppLanguage.fa ? 'اول تخته‌سنگ؟' : 'Boulder first?',
        sub: lang == AppLanguage.fa
            ? 'تفریح بعد از افتادنِ تخته‌سنگ، واقعاً بی‌گناه می‌شود. الان مطمئنی؟'
            : 'Play after the Boulder is truly guilt-free. Are you sure right now?',
        yesLabel: lang == AppLanguage.fa ? 'صبر می‌کنم' : "I'll wait",
        noLabel: lang == AppLanguage.fa ? 'به‌هرحال شروع کن' : 'Start anyway',
      );
      if (!context.mounted || goBoulder) return;
    }

    unawaited(
      startFocusFlow(
        context,
        ref,
        taskId: null,
        title: activeFun.title,
        kind: 'fun',
        fixedMinutes: activeFun.minutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = (plan?.planned ?? false) && !(plan?.boulderDone ?? false);
    final currentFun =
        fun ??
        FunConfig(
          title: lang == AppLanguage.fa
              ? 'تفریح بدون عذاب وجدان'
              : 'Guilt-Free Play',
          minutes: 30,
        );

    final durationLabel = lang == AppLanguage.fa
        ? '${L10n.fmtNum(currentFun.minutes, lang)} دقیقه'
        : '${L10n.fmtNum(currentFun.minutes, lang)} min';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        Reveal(child: _Header(lang: lang)),
        const SizedBox(height: 20),
        Reveal(
          order: 1,
          child: GlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Tone.ember.withValues(alpha: .14),
                        border: Border.all(
                          color: Tone.ember.withValues(alpha: .35),
                        ),
                      ),
                      child: Icon(
                        Icons.spa_rounded,
                        size: 24,
                        color: Tone.ember,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentFun.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: Tone.ink3,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    durationLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Tone.ink2,
                                    ),
                                  ),
                                ],
                              ),
                              if (locked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Tone.warn.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Tone.warn.withValues(alpha: .3),
                                    ),
                                  ),
                                  child: Text(
                                    lang == AppLanguage.fa
                                        ? 'قبل از تخته‌سنگ'
                                        : 'Before Boulder',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Tone.warn,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Tone.ink3,
                      ),
                      onPressed: () => _edit(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: Pill(
                    L10n.startLeisurePlay(lang),
                    style: PillStyle.ember,
                    expanded: false,
                    onTap: () => _startPlay(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Reveal(
          order: 2,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: Tone.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        L10n.leisurePhilosophyTitle(lang),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  L10n.leisurePhilosophyBody(lang),
                  style: TextStyle(fontSize: 13, color: Tone.ink2, height: 1.7),
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.leisureTab(lang),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            L10n.leisureSubtitle(lang),
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
