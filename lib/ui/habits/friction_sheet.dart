import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Friction engineering: when tempted, a forced 10-second pause with the
/// long-term cost in view — then a one-tap replacement (same cue, new
/// response) or an honest slip log. No shame, just data.
Future<void> openFrictionSheet(BuildContext context, Habit habit) {
  return showGlassSheet(
    context,
    isDismissible: false,
    builder: (_) => _FrictionSheet(habit: habit),
  );
}

class _FrictionSheet extends ConsumerStatefulWidget {
  final Habit habit;
  const _FrictionSheet({required this.habit});

  @override
  ConsumerState<_FrictionSheet> createState() => _FrictionSheetState();
}

class _FrictionSheetState extends ConsumerState<_FrictionSheet>
    with SingleTickerProviderStateMixin {
  static const _waitSeconds = 10;
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _waitSeconds),
  )..forward();

  @override
  void initState() {
    super.initState();
    _countdown.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  bool get _unlocked => _countdown.isCompleted;
  int get _secondsLeft =>
      (_waitSeconds * (1 - _countdown.value)).ceil().clamp(0, _waitSeconds);

  Future<void> _log(String status, AppLanguage lang) async {
    await ref.read(habitsProvider.notifier).log(widget.habit.id, status);
    if (!mounted) return;
    Navigator.pop(context);
    if (status == 'resisted') {
      unawaited(HapticFeedback.mediumImpact());
      showToast(
        context,
        lang == AppLanguage.fa
            ? 'همین است. همان محرک، پاسخِ جدید.'
            : 'That\'s it. Same cue, new response.',
      );
    } else {
      showToast(
        context,
        lang == AppLanguage.fa
            ? 'ثبت شد. بدونِ سرزنش — فردا مقاومت آسان‌تر است.'
            : 'Logged. No blame — resistance gets easier tomorrow.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final h = widget.habit;
    final replacement = h.replacement.isEmpty
        ? (lang == AppLanguage.fa ? 'دو دقیقه قدم بزن' : 'Walk for two minutes')
        : h.replacement;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            lang == AppLanguage.fa ? 'صبر کن' : 'Pause',
            sub: lang == AppLanguage.fa
                ? 'ده ثانیه. فقط ده ثانیه بین تو و انتخابِ آگاهانه.'
                : 'Ten seconds. Just 10 seconds between you and a conscious choice.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Tone.warn.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Tone.warn.withValues(alpha: .15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        lang == AppLanguage.fa
                            ? 'هزینهٔ بلندمدتِ «${h.title}»'
                            : 'Long-term cost of "${h.title}"',
                        style: TextStyle(fontSize: 11, color: Tone.ink3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        h.badCost.isEmpty
                            ? (lang == AppLanguage.fa
                                  ? 'به اهداف بلندمدتت فکر کن.'
                                  : 'Think about your long-term goals.')
                            : h.badCost,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.9,
                          color: Tone.warn.withValues(alpha: .85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: 1 - _countdown.value,
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: Tone.warn,
                          backgroundColor: Colors.white.withValues(alpha: .08),
                        ),
                      ),
                      Text(
                        _unlocked ? '—' : L10n.fmtNum(_secondsLeft, lang),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w300,
                          color: Tone.warn,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _unlocked ? 1 : .35,
                  child: Column(
                    children: [
                      Pill(
                        lang == AppLanguage.fa
                            ? 'به‌جایش: $replacement'
                            : 'Instead: $replacement',
                        style: PillStyle.ember,
                        icon: Icons.swap_horiz_rounded,
                        onTap: _unlocked ? () => _log('resisted', lang) : null,
                      ),
                      const SizedBox(height: 10),
                      Pill(
                        lang == AppLanguage.fa
                            ? 'انجامش دادم (ثبتِ لغزش)'
                            : 'Did it (Log slip)',
                        style: PillStyle.quiet,
                        onTap: _unlocked ? () => _log('slip', lang) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
