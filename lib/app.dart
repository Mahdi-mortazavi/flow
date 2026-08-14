import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'state/providers.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/today/today_screen.dart';

class TakNoghteApp extends ConsumerWidget {
  const TakNoghteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLanguage = ref.watch(appLanguageProvider);
    final accent = ref.watch(accentProvider);
    Tone.setAccent(accent.color);
    return MaterialApp(
      title: L10n.appTitle(appLanguage),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(accent.color),
      scrollBehavior: const AppScrollBehavior(),
      locale: Locale(appLanguage.code),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Respect the system font size up to 1.3× — beyond that the dense
      // glass cards would overflow instead of helping anyone.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child!,
        );
      },
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
