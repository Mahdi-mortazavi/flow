import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
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
    final lang = ref.watch(appLanguageProvider);
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
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
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
                  Text(
                    L10n.statsMirrorTitle(lang),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    L10n.realityWithoutJudgment(lang),
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
            _stat('${_fmt(s.winRate, lang)}٪', L10n.winRateSub(lang)),
            const SizedBox(width: 9),
            _stat(
              !s.optimismReliable || s.gap == null
                  ? '—'
                  : '${s.gap! > 0 ? '+' : ''}${L10n.fmtNum(s.gap!, lang)}',
              L10n.optimismGapSub(lang),
              warn: s.optimismReliable && (s.gap ?? 0) > 15,
            ),
            const SizedBox(width: 9),
            _stat('${_fmt(s.recoveryRate, lang)}٪', L10n.recoveryRateSub(lang)),
          ],
        ),
        if (!s.optimismReliable)
          _hint(
            lang == AppLanguage.fa
                ? 'خوش‌بینیِ پیش‌بینی بعد از ${L10n.fmtNum(StatsData.optimismMinNights, lang)} شبِ بسته معنا پیدا می‌کند — فعلاً داده کم است.'
                : 'Optimism gap becomes meaningful after ${L10n.fmtNum(StatsData.optimismMinNights, lang)} closed nights — data is insufficient for now.',
          )
        else if ((s.gap ?? 0) > 15)
          _hint(
            lang == AppLanguage.fa
                ? 'پیش‌بینی‌هایت به‌طور میانگین ${L10n.fmtNum(s.gap!, lang)} واحد خوش‌بینانه است — فردا صبح، عدد را صادقانه‌تر بگذار.'
                : 'Your predictions are on average ${L10n.fmtNum(s.gap!, lang)} points optimistic — calibrate more honestly tomorrow morning.',
          ),
        if (s.recoveryRate != null)
          _hint(
            lang == AppLanguage.fa
                ? '«بازگشت» مهم‌ترین عدد این صفحه است: قهرمانِ عادت کسی نیست که هرگز نمی‌افتد؛ کسی است که فردایش برمی‌گردد.'
                : '"Recovery" is the most important metric on this screen: a habit hero isn\'t someone who never slips, but someone who returns the next day.',
          ),
        const SizedBox(height: 24),
        _eyebrow(L10n.last7DaysFocusChartTitle(lang)),
        FocusChart(minutes: s.focusMinutesLast7, lang: lang),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Text(
            lang == AppLanguage.fa
                ? 'مجموع این هفته: ${L10n.fmtNum((s.focusMinutesWeek / 60).toStringAsFixed(1), lang)} ساعت'
                : 'Total this week: ${L10n.fmtNum((s.focusMinutesWeek / 60).toStringAsFixed(1), lang)} hours',
            style: TextStyle(fontSize: 11.5, color: Tone.ink2),
          ),
        ),
        if (s.goldenHour != null) ...[
          const SizedBox(height: 24),
          _eyebrow(L10n.goldenHour(lang)),
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 20, color: Tone.ember),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lang == AppLanguage.fa
                        ? 'اوج انرژی تو حدود ساعت ${L10n.fmtNum(s.goldenHour!, lang)} تا ${L10n.fmtNum(s.goldenHour! + 3, lang)} است — تخته‌سنگ را همان‌جا بگذار.'
                        : 'Your peak focus time is around ${L10n.fmtNum(s.goldenHour!, lang)}:00 to ${L10n.fmtNum(s.goldenHour! + 3, lang)}:00 — place The Boulder right there.',
                    style: const TextStyle(fontSize: 13.5, height: 1.8),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (s.interruptCounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          _eyebrow(L10n.rankedPatterns30DaysTitle(lang)),
          _InterruptPattern(counts: s.interruptCounts, lang: lang),
        ],
        const SizedBox(height: 24),
        _eyebrow(lang == AppLanguage.fa ? 'هفت شبِ آخر' : 'Last Seven Nights'),
        if (s.lastNights.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                lang == AppLanguage.fa
                    ? 'هنوز شبی بسته نشده.'
                    : 'No nights recorded yet.',
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
                            L10n.fmtDayLabel(n.dayKey, lang),
                            style: TextStyle(fontSize: 12.5, color: Tone.ink3),
                          ),
                        ),
                        Text(
                          lang == AppLanguage.fa
                              ? 'پیش‌بینی ${L10n.fmtNum(n.prediction, lang)}٪'
                              : 'Prediction ${L10n.fmtNum(n.prediction, lang)}%',
                          style: TextStyle(fontSize: 12.5, color: Tone.ink2),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          n.outcome
                              ? (lang == AppLanguage.fa ? 'افتاد' : 'Fell')
                              : (lang == AppLanguage.fa ? 'نیفتاد' : 'Missed'),
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
          L10n.weeklyReviewTitle(lang),
          icon: Icons.filter_list_rounded,
          onTap: () => openReviewSheet(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
          child: Text(
            lang == AppLanguage.fa
                ? 'برای هر کار و عادت فقط یک سؤال: «اگر امروز در لیست نبود، دوباره اضافه‌اش می‌کردی؟»'
                : 'For each task and habit, just one question: "If it wasn\'t on the list today, would you add it again?"',
            style: TextStyle(fontSize: 11, color: Tone.ink3, height: 1.8),
          ),
        ),
      ],
    );
  }

  String _fmt(int? v, AppLanguage lang) =>
      v == null ? '—' : L10n.fmtNum(v, lang);

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

/// Seven slim bars, today at the end.
class FocusChart extends StatelessWidget {
  final List<int> minutes;
  final AppLanguage lang;
  const FocusChart({
    super.key,
    required this.minutes,
    this.lang = AppLanguage.fa,
  });

  @override
  Widget build(BuildContext context) {
    final maxM = minutes.fold(0, (a, b) => a > b ? a : b);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: SizedBox(
        height: 118,
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
                        L10n.fmtNum(minutes[i], lang),
                        style: TextStyle(fontSize: 9, color: Tone.ink3),
                      ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Tone.easeOut,
                      height: maxM == 0 ? 3 : 3 + 52 * (minutes[i] / maxM),
                      decoration: BoxDecoration(
                        color: i == 6
                            ? Tone.ember
                            : Tone.ember.withValues(alpha: .30),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i == 6
                          ? (lang == AppLanguage.fa ? 'امروز' : 'Today')
                          : '',
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

/// Ranked interrupt reasons as labeled bars.
class _InterruptPattern extends StatelessWidget {
  final Map<InterruptTag, int> counts;
  final AppLanguage lang;
  const _InterruptPattern({required this.counts, required this.lang});

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
                      '${e.key.emoji}  ${_tagLabel(e.key, lang)}',
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
                    L10n.fmtNum(e.value, lang),
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

  String _tagLabel(InterruptTag tag, AppLanguage lang) {
    if (lang == AppLanguage.fa) return tag.label;
    return switch (tag) {
      InterruptTag.phone => 'Phone',
      InterruptTag.people => 'People',
      InterruptTag.tired => 'Fatigue',
      InterruptTag.thought => 'Thought',
      InterruptTag.other => 'Other',
    };
  }
}
