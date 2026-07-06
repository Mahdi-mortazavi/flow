import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../today/today_screen.dart';
import '../widgets/glass.dart';

const onboardedKey = 'onboarded_v1';

/// Apple-style onboarding: one idea per screen, oversized type, generous
/// whitespace, a single warm accent. Swipe through, or skip — the app
/// itself is the real tutorial.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final Widget visual;
  final String title;
  final String body;
  const _Slide({required this.visual, required this.title, required this.body});
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  var _page = 0;

  static final _slides = [
    const _Slide(
      visual: _EmberDot(),
      title: 'تک‌نقطه',
      body:
          'هر روز، فقط یک نقطهٔ داغ.\nبقیهٔ کارها پشتِ آن صف می‌کشند.\nذهنِ شلوغ، این‌طور آرام می‌شود.',
    ),
    _Slide(
      visual: _icon(Icons.local_fire_department_rounded),
      title: 'تخته‌سنگ و پیش‌بینی',
      body:
          'صبح، مهم‌ترین کار را ستاره می‌زنی و صادقانه پیش‌بینی می‌کنی.\nشب چک می‌شود — بدون سرزنش،\nفقط برای اینکه ذهنت کالیبره شود.',
    ),
    _Slide(
      visual: _icon(Icons.restart_alt_rounded),
      title: 'عادت‌هایی که برمی‌گردند',
      body:
          'اینجا زنجیرِ تنبیهی نداریم.\nقهرمانِ عادت کسی است که فردایِ شکست برمی‌گردد.\nما همان روز را می‌شماریم.',
    ),
    _Slide(
      visual: _icon(Icons.lock_rounded),
      title: 'فقط روی گوشیِ تو',
      body:
          'بدون اکانت، بدون سرور، بدون ردیابی.\nهمه‌چیز همین‌جا می‌ماند.\nآماده‌ای؟ روزت را بچین.',
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

  @override
  Widget build(BuildContext context) {
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
                    'رد شدن',
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        s.visual,
                        const SizedBox(height: 40),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Tone.ink2,
                            height: 2.1,
                          ),
                        ),
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
                last ? 'شروع' : 'بعدی',
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
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF6B26E), Color(0xFFE7994C)],
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
