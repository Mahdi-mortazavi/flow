import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Design tokens — faithful to the liquid-glass ember language of taknoghte 2:
/// a near-black canvas, monochrome glass surfaces, and exactly one warm color
/// (ember) reserved for the boulder and primary actions.
abstract final class Tone {
  static const bg = Color(0xFF060608);
  static const ink = Color(0xFFF5F5F7);
  static Color get ink2 => ink.withValues(alpha: .55);
  // a11y: informational text kept at ≥38% white for contrast on the dark bg.
  static Color get ink3 => ink.withValues(alpha: .38);

  static const ember = Color(0xFFEFA55C);
  static const emberInk = Color(0xFF1C1207);
  static Color get emberSoft => ember.withValues(alpha: .13);
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

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Vazirmatn',
    scaffoldBackgroundColor: Tone.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Tone.ember,
      brightness: Brightness.dark,
      surface: Tone.bg,
      primary: Tone.ember,
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
      cursorColor: Tone.ember,
      selectionColor: Tone.ember.withValues(alpha: .28),
      selectionHandleColor: Tone.ember,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Tone.ember.withValues(alpha: .85),
      inactiveTrackColor: Colors.white.withValues(alpha: .12),
      thumbColor: Colors.white,
      overlayColor: Tone.ember.withValues(alpha: .10),
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
