import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/today/today_screen.dart';

class TakNoghteApp extends StatelessWidget {
  const TakNoghteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تک‌نقطه',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scrollBehavior: const AppScrollBehavior(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Gate(),
    );
  }
}

/// Decides between onboarding (first launch) and the app itself,
/// without a flash of the wrong screen.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _onboarded = prefs.getBool(onboardedKey) ?? false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_onboarded) {
      null => const Scaffold(body: SizedBox.shrink()),
      false => const OnboardingScreen(),
      true => const TodayScreen(),
    };
  }
}
