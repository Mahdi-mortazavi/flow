import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../state/providers.dart';
import '../today/today_screen.dart';
import '../widgets/glass.dart';

const onboardedKey = 'onboarded_v1';

/// Apple-style onboarding: one idea per screen, oversized type, generous
/// whitespace, a single warm accent. The last screen does real work — it
/// sets the two reminder times that keep the daily loop alive.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _SlideData {
  final Widget visual;
  final String Function(AppLanguage) title;
  final String Function(AppLanguage) body;
  const _SlideData({
    required this.visual,
    required this.title,
    required this.body,
  });
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _page = 0;
  var _morning = Repo.defaultMorningMin;
  var _evening = Repo.defaultEveningMin;

  static final _slides = [
    const _SlideData(
      visual: _EmberDot(),
      title: L10n.onboardingSlide1Title,
      body: L10n.onboardingSlide1Body,
    ),
    _SlideData(
      visual: _icon(Icons.local_fire_department_rounded),
      title: L10n.onboardingSlide2Title,
      body: L10n.onboardingSlide2Body,
    ),
    _SlideData(
      visual: _icon(Icons.restart_alt_rounded),
      title: (lang) => lang == AppLanguage.fa
          ? 'عادت‌هایی که برمی‌گردند'
          : 'Habits that bounce back',
      body: (lang) => lang == AppLanguage.fa
          ? 'اینجا زنجیرِ تنبیهی نداریم.\nقهرمانِ عادت کسی است که فردایِ شکست برمی‌گردد.\nما همان روز را می‌شماریم.'
          : 'No punitive streak breaks here.\nA habit hero is someone who returns the day after a slip.\nWe count that recovery day.',
    ),
    _SlideData(
      visual: _icon(Icons.notifications_active_rounded),
      title: L10n.onboardingSlide3Title,
      body: (lang) => lang == AppLanguage.fa
          ? 'صبح، یک یادآوریِ چیدن.\nشب، یک یادآوریِ بستن.\nهمه‌چیز فقط روی گوشیِ خودت می‌ماند — بدون اکانت، بدون ردیابی.'
          : 'Morning: a kickoff reminder.\nNight: a closure review.\nEverything stays strictly on your device — no account, no tracking.',
    ),
  ];

  static Widget _icon(IconData icon) => Container(
    width: 96,
    height: 96,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Tone.glassA, Tone.glassB],
      ),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Tone.line),
    ),
    child: Icon(icon, size: 40, color: Tone.ember),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardedKey, true);
    // Persist the two daily nudges and put them on the OS scheduler.
    final repo = ref.read(repoProvider);
    await repo.setReminderMinutes('rem_morning', _morning);
    await repo.setReminderMinutes('rem_evening', _evening);
    await syncDailyReminders(
      repo,
      ref.read(dayKeyProvider),
      ref.read(appLanguageProvider),
    );
    if (!mounted) return;
    unawaited(
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const TodayScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      ),
    );
  }

  Widget _reminderRow(
    String label,
    int value,
    AppLanguage lang,
    ValueChanged<int> onChanged,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () async {
        final v = await showWheelTimePicker(
          context,
          initialMinutes: value,
          title: label,
        );
        if (v != null) onChanged(v);
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            L10n.fmtNum(
              '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}',
              lang,
            ),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Tone.ember,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Pressable(
                onTap: _finish,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    lang == AppLanguage.fa ? 'رد شدن' : 'Skip',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Tone.ink3,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = i);
                },
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  final isLast = i == _slides.length - 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        s.visual,
                        const SizedBox(height: 40),
                        Text(
                          s.title(lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          s.body(lang),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Tone.ink2,
                            height: 2.1,
                          ),
                        ),
                        if (isLast) ...[
                          const SizedBox(height: 26),
                          _reminderRow(
                            L10n.morningReminder(lang),
                            _morning,
                            lang,
                            (v) => setState(() => _morning = v),
                          ),
                          const SizedBox(height: 8),
                          _reminderRow(
                            L10n.eveningReminder(lang),
                            _evening,
                            lang,
                            (v) => setState(() => _evening = v),
                          ),
                        ],
                        const SizedBox(height: 60),
                      ],
                    ),
                  );
                },
              ),
            ),
            // dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Tone.easeOut,
                    width: i == _page ? 22 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _page
                          ? Tone.ember
                          : Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 30),
              child: Pill(
                last
                    ? (lang == AppLanguage.fa ? 'شروع' : 'Start')
                    : L10n.next(lang),
                style: PillStyle.ember,
                onTap: () {
                  if (last) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 450),
                      curve: Tone.easeOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single warm point, breathing slowly.
class _EmberDot extends StatefulWidget {
  const _EmberDot();

  @override
  State<_EmberDot> createState() => _EmberDotState();
}

class _EmberDotState extends State<_EmberDot>
    with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_breath.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Tone.ember.withValues(alpha: .18 + .12 * t),
                      Tone.ember.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Container(
                width: 26 + 4 * t,
                height: 26 + 4 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Tone.accentLight, Tone.accentDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Tone.ember.withValues(alpha: .5),
                      blurRadius: 30 + 12 * t,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
