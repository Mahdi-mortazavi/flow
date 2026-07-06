import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'ui/today/today_screen.dart';

class TakNoghteApp extends StatelessWidget {
  const TakNoghteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تک‌نقطه',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const TodayScreen(),
    );
  }
}
