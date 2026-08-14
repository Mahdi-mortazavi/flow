// ignore: unnecessary_import
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'l10n.dart';

/// Selectable Liquid Glass accent color palettes.
enum AppAccent {
  ember(Color(0xFFEFA55C), 'ember'),
  pine(Color(0xFF4EAF7B), 'pine'),
  indigo(Color(0xFF5486EB), 'indigo'),
  mulberry(Color(0xFFD65B6E), 'mulberry'),
  slate(Color(0xFFA2ADC0), 'slate'),
  iris(Color(0xFF9F7AEA), 'iris');

  final Color color;
  final String code;
  const AppAccent(this.color, this.code);

  static AppAccent fromCode(String? code) {
    return AppAccent.values.firstWhere(
      (a) => a.code == code,
      orElse: () => AppAccent.ember,
    );
  }

  String label(AppLanguage lang) {
    if (lang == AppLanguage.fa) {
      switch (this) {
        case AppAccent.ember:
          return 'کهربایی';
        case AppAccent.pine:
          return 'سوزن کاج';
        case AppAccent.indigo:
          return 'نیلی ژرف';
        case AppAccent.mulberry:
          return 'شاتوتی';
        case AppAccent.slate:
          return 'گرانیت مهآلود';
        case AppAccent.iris:
          return 'شفق شبانه';
      }
    } else {
      switch (this) {
        case AppAccent.ember:
          return 'Ember';
        case AppAccent.pine:
          return 'Alpine Pine';
        case AppAccent.indigo:
          return 'Abyssal Indigo';
        case AppAccent.mulberry:
          return 'Smoked Mulberry';
        case AppAccent.slate:
          return 'Mist Slate';
        case AppAccent.iris:
          return 'Night Iris';
      }
    }
  }
}

/// Design tokens — faithful to the liquid-glass ember language of taknoghte 2:
/// a near-black canvas, monochrome glass surfaces, and exactly one warm color
/// (accent) reserved for the boulder and primary actions.
abstract final class Tone {
  static const bg = Color(0xFF060608);
  static const ink = Color(0xFFF5F5F7);
  static Color get ink2 => ink.withValues(alpha: .55);
  // a11y: informational text kept at ≥38% white for contrast on the dark bg.
  static Color get ink3 => ink.withValues(alpha: .38);

  static Color _accent = const Color(0xFFEFA55C);

  /// Dynamically reflects the user's active accent color selection.
  static Color get ember => _accent;
  static Color get accent => _accent;
  static const emberInk = Color(0xFF1C1207);
  static Color get emberSoft => _accent.withValues(alpha: .13);
  static const warn = Color(0xFFFF7A6E);

  static Color get glassA => Colors.white.withValues(alpha: .072);
  static Color get glassB => Colors.white.withValues(alpha: .030);
  static Color get line => Colors.white.withValues(alpha: .085);
  static Color get spec => Colors.white.withValues(alpha: .16);

  static const rCard = 26.0;
  static const rSmall = 20.0;
  static const rPill = 17.0;

  static const easeOut = Cubic(.16, 1, .3, 1);
  static const dur = Duration(milliseconds: 420);

  static void setAccent(Color color) {
    _accent = color;
  }
}

/// iOS-feel scrolling everywhere: rubber-band bounce instead of glow.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

ThemeData buildTheme([Color? accentColor]) {
  final accent = accentColor ?? Tone.ember;
  Tone.setAccent(accent);
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Vazirmatn',
    scaffoldBackgroundColor: Tone.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: Tone.bg,
      primary: accent,
      onPrimary: Tone.emberInk,
      error: Tone.warn,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Tone.ink,
      displayColor: Tone.ink,
      fontFamily: 'Vazirmatn',
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: .28),
      selectionHandleColor: accent,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent.withValues(alpha: .85),
      inactiveTrackColor: Colors.white.withValues(alpha: .12),
      thumbColor: Colors.white,
      overlayColor: accent.withValues(alpha: .10),
      trackHeight: 5,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    // Apple-style horizontal slide with edge-swipe back on every route.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
