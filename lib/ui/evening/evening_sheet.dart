import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// 60 seconds, honestly: final check, the why-chain if the boulder didn't
/// fall, one line for the day.
Future<void> openEveningSheet(BuildContext context, WidgetRef ref) {
  return showGlassSheet(context, builder: (_) => const _EveningSheet());
}

class _EveningSheet extends ConsumerStatefulWidget {
  const _EveningSheet();

  @override
  ConsumerState<_EveningSheet> createState() => _EveningSheetState();
}

class _EveningSheetState extends ConsumerState<_EveningSheet> {
  final _whys = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final _note = TextEditingController();
  var _whyVisible = 1;

  @override
  void dispose() {
    for (final c in _whys) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final lang = ref.read(appLanguageProvider);
    final plan = await ref.read(todayProvider.future);
    final whys = _whys
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (!plan.boulderDone && whys.isEmpty) {
      if (mounted) {
        showToast(context, L10n.toastAtLeastOneWhy(lang));
      }
      return;
    }
    await ref
        .read(todayProvider.notifier)
        .closeDay(whys: whys, note: _note.text.trim());
    if (!mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    Navigator.pop(context);
    showToast(
      context,
      plan.boulderDone
          ? L10n.toastRecordedWinningDay(lang)
          : L10n.toastRecordedImprovedSystem(lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accentProvider);
    final lang = ref.watch(appLanguageProvider);
    final planAsync = ref.watch(todayProvider);
    return planAsync.when(
      loading: () => const SizedBox(height: 200),
      error: (e, _) => SizedBox(height: 200, child: Center(child: Text('$e'))),
      data: (plan) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            L10n.eveningReviewTitle(lang),
            sub: lang == AppLanguage.fa
                ? 'شصت ثانیه. صادقانه.'
                : '60 seconds. Honestly.',
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    lang == AppLanguage.fa ? 'چک نهایی' : 'Final Check',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Tone.ink3,
                    ),
                  ),
                ),
                for (final t in plan.tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          CheckCircle(
                            on: t.done,
                            onTap: () => ref
                                .read(todayProvider.notifier)
                                .setTaskDone(t.taskId, !t.done),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: t.title,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: t.done ? Tone.ink3 : Tone.ink,
                                  decoration: t.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                children: [
                                  if (t.taskId == plan.boulderId)
                                    TextSpan(
                                      text: '  ${L10n.theBoulder(lang)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Tone.ember,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _whyChain(plan.boulderDone, plan.prediction, lang),
                const SizedBox(height: 16),
                GlassField(
                  controller: _note,
                  label: L10n.nightNoteLabel(lang),
                  hint: L10n.nightNoteHint(lang),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Pill(
              L10n.confirmCloseDayAction(lang),
              style: PillStyle.ember,
              onTap: _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whyChain(bool boulderDone, int? prediction, AppLanguage lang) {
    if (boulderDone) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          lang == AppLanguage.fa
              ? 'تخته‌سنگ افتاد — پیش‌بینی‌ات ${L10n.fmtNum(prediction ?? 0, lang)}٪ بود. ثبت می‌شود.'
              : 'The Boulder fell — your prediction was ${L10n.fmtNum(prediction ?? 0, lang)}%. Recording.',
          style: TextStyle(fontSize: 11.5, color: Tone.ember, height: 1.9),
        ),
      );
    }
    final hints = [
      L10n.whyHint(0, lang),
      L10n.whyHint(1, lang),
      L10n.whyHint(2, lang),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(
            lang == AppLanguage.fa
                ? 'تخته‌سنگ نیفتاد. بدونِ سرزنش — فقط زنجیرهٔ چرا، تا علتِ سیستمی:'
                : 'The Boulder didn\'t fall. No blame — just the why-chain to the systemic cause:',
            style: TextStyle(fontSize: 11.5, color: Tone.ink3, height: 1.9),
          ),
        ),
        for (var i = 0; i < 3; i++)
          if (i < _whyVisible)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GlassField(
                controller: _whys[i],
                hint: hints[i],
                onChanged: (v) {
                  if (v.trim().isNotEmpty && _whyVisible == i + 1) {
                    setState(() => _whyVisible = i + 2);
                  }
                },
              ),
            ),
      ],
    );
  }
}
