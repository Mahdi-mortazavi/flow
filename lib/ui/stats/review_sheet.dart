import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Zero-based review: one item at a time, one question —
/// «اگر امروز در لیست نبود، دوباره اضافه‌اش می‌کردی؟»
Future<void> openReviewSheet(BuildContext context) {
  return showGlassSheet(context, builder: (_) => const _ReviewSheet());
}

class _ReviewItem {
  final String kind;
  final String title;
  final bool isHabit;
  final String id;
  const _ReviewItem(this.kind, this.title, this.isHabit, this.id);
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet();

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  List<_ReviewItem>? _items;
  var _index = 0;
  var _kept = 0;
  // Deletions are collected here and only committed at the end, so
  // abandoning the sheet halfway loses nothing.
  final _toCut = <_ReviewItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lang = ref.read(appLanguageProvider);
    final repo = ref.read(repoProvider);
    final backlog = await repo.backlog();
    final habits = await repo.habits();
    if (!mounted) return;
    final taskKind = lang == AppLanguage.fa ? 'کار' : 'Task';
    final habitKind = lang == AppLanguage.fa ? 'عادت' : 'Habit';
    final afterText = lang == AppLanguage.fa ? 'بعد از' : 'after';
    setState(() {
      _items = [
        for (final b in backlog) _ReviewItem(taskKind, b.title, false, b.id),
        for (final h in habits)
          _ReviewItem(
            habitKind,
            '${h.title} — $afterText ${h.cue}',
            true,
            h.id,
          ),
      ];
    });
  }

  Future<void> _answer(bool keep) async {
    final items = _items;
    if (items == null || _index >= items.length) return;
    if (keep) {
      _kept++;
    } else {
      _toCut.add(items[_index]);
    }
    setState(() => _index++);
    if (_index >= items.length) {
      // Commit everything at once, only now.
      for (final item in _toCut) {
        if (item.isHabit) {
          await ref.read(habitsProvider.notifier).remove(item.id);
        } else {
          await ref.read(repoProvider).deleteBacklog(item.id);
        }
      }
      await ref.read(repoProvider).markReviewDone();
      ref.invalidate(statsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final items = _items;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(L10n.weeklyReviewTitle(lang)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text.rich(
            TextSpan(
              text: lang == AppLanguage.fa
                  ? 'برای هر مورد فقط یک سؤال:\n'
                  : 'Just one question for each item:\n',
              children: [
                TextSpan(
                  text: lang == AppLanguage.fa
                      ? '«اگر امروز در لیست نبود، دوباره اضافه‌اش می‌کردی؟»'
                      : '"If it wasn\'t on the list today, would you add it again?"',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Tone.ink,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Tone.ink2, height: 2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: switch (items) {
            null => const SizedBox(height: 120),
            [] => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                lang == AppLanguage.fa
                    ? 'چیزی برای بازبینی نیست.'
                    : 'Nothing to review.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Tone.ink3),
              ),
            ),
            _ when _index >= items.length => _summary(lang),
            _ => _card(items, lang),
          },
        ),
      ],
    );
  }

  Widget _card(List<_ReviewItem> items, AppLanguage lang) {
    final item = items[_index];
    return Column(
      children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          child: Column(
            children: [
              Text(
                item.kind,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Tone.ink3,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= _index
                      ? Tone.ember
                      : Colors.white.withValues(alpha: .14),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Pill(
                lang == AppLanguage.fa ? 'نه — حذف' : 'No — Remove',
                style: PillStyle.quiet,
                onTap: () => _answer(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pill(
                lang == AppLanguage.fa ? 'بله — می‌ماند' : 'Yes — Keep',
                style: PillStyle.ember,
                onTap: () => _answer(true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summary(AppLanguage lang) {
    return Column(
      children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          child: Column(
            children: [
              Text(
                lang == AppLanguage.fa ? 'تمام' : 'Complete',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Tone.ink3,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                lang == AppLanguage.fa
                    ? '${L10n.fmtNum(_kept, lang)} ماند · ${L10n.fmtNum(_toCut.length, lang)} حذف شد'
                    : '${L10n.fmtNum(_kept, lang)} kept · ${L10n.fmtNum(_toCut.length, lang)} removed',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                lang == AppLanguage.fa
                    ? 'هر چیزی که ماند، حالا آگاهانه مانده.'
                    : 'Everything that remains is now kept consciously.',
                style: TextStyle(fontSize: 11.5, color: Tone.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Pill(
          L10n.close(lang),
          style: PillStyle.ember,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
