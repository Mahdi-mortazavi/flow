import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Zero-based review: one item at a time, one question —
/// «اگر امروز در لیست نبود، دوباره اضافه‌اش می‌کردی؟»
Future<void> openReviewSheet(BuildContext context) {
  return showGlassSheet(context, builder: (_) => const _ReviewSheet());
}

class _ReviewItem {
  final String kind; // کار | عادت
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
    final repo = ref.read(repoProvider);
    final backlog = await repo.backlog();
    final habits = await repo.habits();
    if (!mounted) return;
    setState(() {
      _items = [
        for (final b in backlog) _ReviewItem('کار', b.title, false, b.id),
        for (final h in habits)
          _ReviewItem('عادت', '${h.title} — بعد از ${h.cue}', true, h.id),
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
    final items = _items;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader('بازبینیِ مبنا-صفر'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text.rich(
            const TextSpan(
              text: 'برای هر مورد فقط یک سؤال:\n',
              children: [
                TextSpan(
                  text: '«اگر امروز در لیست نبود، دوباره اضافه‌اش می‌کردی؟»',
                  style: TextStyle(
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
                'چیزی برای بازبینی نیست.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Tone.ink3),
              ),
            ),
            _ when _index >= items.length => _summary(),
            _ => _card(items),
          },
        ),
      ],
    );
  }

  Widget _card(List<_ReviewItem> items) {
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
                'نه — حذف',
                style: PillStyle.quiet,
                onTap: () => _answer(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pill(
                'بله — می‌ماند',
                style: PillStyle.ember,
                onTap: () => _answer(true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summary() {
    return Column(
      children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          child: Column(
            children: [
              Text(
                'تمام',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Tone.ink3,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '${faNum(_kept)} ماند · ${faNum(_toCut.length)} حذف شد',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'هر چیزی که ماند، حالا آگاهانه مانده.',
                style: TextStyle(fontSize: 11.5, color: Tone.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Pill(
          'بستن',
          style: PillStyle.ember,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
