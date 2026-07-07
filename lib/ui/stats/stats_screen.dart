import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';
import 'review_sheet.dart';

/// The mirror: numbers are not judgment — they are data for tuning tomorrow.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const StatsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) =>
                  ErrorCard(onRetry: () => ref.invalidate(statsProvider)),
              data: (s) => _StatsBody(stats: s),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  final StatsData stats;
  const _StatsBody({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
      children: [
        Row(
          children: [
            Pressable(
              onTap: () => Navigator.pop(context),
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
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 19,
                  color: Tone.ink2,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'آینه',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'این اعداد قضاوت نیستند؛ داده‌اند برای تنظیمِ فردا.',
                    style: TextStyle(fontSize: 11.5, color: Tone.ink3),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _stat('${_fmt(s.winRate)}٪', 'تخته‌سنگ‌های افتاده'),
            const SizedBox(width: 9),
            // Optimism is noisy below a handful of nights — hide the number
            // (and the warning color) until it means something.
            _stat(
              !s.optimismReliable || s.gap == null
                  ? '—'
                  : '${s.gap! > 0 ? '+' : ''}${faNum(s.gap!)}',
              'خوش‌بینیِ پیش‌بینی',
              warn: s.optimismReliable && (s.gap ?? 0) > 15,
            ),
            const SizedBox(width: 9),
            _stat('${_fmt(s.recoveryRate)}٪', 'بازگشت بعد از شکست'),
          ],
        ),
        if (!s.optimismReliable)
          _hint(
            'خوش‌بینیِ پیش‌بینی بعد از ${faNum(StatsData.optimismMinNights)} شبِ بسته معنا پیدا می‌کند — فعلاً داده کم است.',
          )
        else if ((s.gap ?? 0) > 15)
          _hint(
            'پیش‌بینی‌هایت به‌طور میانگین ${faNum(s.gap!)} واحد خوش‌بینانه است — فردا صبح، عدد را صادقانه‌تر بگذار.',
          ),
        if (s.recoveryRate != null)
          _hint(
            '«بازگشت» مهم‌ترین عدد این صفحه است: قهرمانِ عادت کسی نیست که هرگز نمی‌افتد؛ کسی است که فردایش برمی‌گردد.',
          ),
        const SizedBox(height: 24),
        _eyebrow('کارِ عمیق — ۷ روز اخیر'),
        _FocusChart(minutes: s.focusMinutesLast7),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(
            'مجموع این هفته: ${faNum((s.focusMinutesWeek / 60).toStringAsFixed(1))} ساعت',
            style: TextStyle(fontSize: 11.5, color: Tone.ink2),
          ),
        ),
        if (s.goldenHour != null) ...[
          const SizedBox(height: 24),
          _eyebrow('ساعتِ طلایی انرژی'),
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 20, color: Tone.ember),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'اوج انرژی تو حدود ساعت ${faNum(s.goldenHour!)} تا ${faNum(s.goldenHour! + 3)} است — تخته‌سنگ را همان‌جا بگذار.',
                    style: const TextStyle(fontSize: 13.5, height: 1.8),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (s.interruptCounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          _eyebrow('الگوی قطع‌شدن‌ها — ۳۰ روز'),
          _InterruptPattern(counts: s.interruptCounts),
        ],
        const SizedBox(height: 24),
        _eyebrow('هفت شبِ آخر'),
        if (s.lastNights.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'هنوز شبی بسته نشده.',
                style: TextStyle(fontSize: 12.5, color: Tone.ink3),
              ),
            ),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final n in s.lastNights)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: n != s.lastNights.last
                          ? Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: .05),
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            faDayLabel(n.dayKey),
                            style: TextStyle(fontSize: 12.5, color: Tone.ink3),
                          ),
                        ),
                        Text(
                          'پیش‌بینی ${faNum(n.prediction)}٪',
                          style: TextStyle(fontSize: 12.5, color: Tone.ink2),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          n.outcome ? 'افتاد' : 'نیفتاد',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: n.outcome ? Tone.ember : Tone.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 26),
        Pill(
          'بازبینیِ مبنا-صفر',
          icon: Icons.filter_list_rounded,
          onTap: () => openReviewSheet(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Text(
            'برای هر کار و عادت فقط یک سؤال: «اگر امروز در لیست نبود، دوباره اضافه‌اش می‌کردی؟»',
            style: TextStyle(fontSize: 11, color: Tone.ink3, height: 1.8),
          ),
        ),
      ],
    );
  }

  String _fmt(int? v) => v == null ? '—' : faNum(v);

  Widget _stat(String value, String label, {bool warn = false}) => Expanded(
    child: GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: warn ? Tone.warn : Tone.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Tone.ink3,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _eyebrow(String text) => Padding(
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

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, color: Tone.ink3, height: 1.9),
    ),
  );
}

/// Seven slim bars, today at the end (start side in RTL is right).
class _FocusChart extends StatelessWidget {
  final List<int> minutes;
  const _FocusChart({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final maxM = minutes.fold(0, (a, b) => a > b ? a : b);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: SizedBox(
        height: 96,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++) ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (minutes[i] > 0)
                      Text(
                        faNum(minutes[i]),
                        style: TextStyle(fontSize: 9, color: Tone.ink3),
                      ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Tone.easeOut,
                      height: maxM == 0 ? 3 : 3 + 60 * (minutes[i] / maxM),
                      decoration: BoxDecoration(
                        color: i == 6
                            ? Tone.ember
                            : Tone.ember.withValues(alpha: .30),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i == 6 ? 'امروز' : '',
                      style: TextStyle(fontSize: 9, color: Tone.ink3),
                    ),
                  ],
                ),
              ),
              if (i < 6) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ranked interrupt reasons as labeled bars — the actual "pattern", not a
/// list of one-off notes.
class _InterruptPattern extends StatelessWidget {
  final Map<InterruptTag, int> counts;
  const _InterruptPattern({required this.counts});

  @override
  Widget build(BuildContext context) {
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = ranked.first.value;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          for (final e in ranked)
            Padding(
              padding: EdgeInsets.only(
                bottom: e.key == ranked.last.key ? 0 : 12,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      '${e.key.emoji}  ${e.key.label}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Stack(
                        children: [
                          Container(
                            height: 6,
                            color: Colors.white.withValues(alpha: .05),
                          ),
                          FractionallySizedBox(
                            widthFactor: e.value / max,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Tone.ember.withValues(alpha: .55),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    faNum(e.value),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Tone.ink2,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
