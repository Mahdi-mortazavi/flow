import 'dart:ui';

import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// The liquid-glass surface every card in the app sits on.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool emberRing;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = Tone.rSmall,
    this.emberRing = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Tone.glassA, Tone.glassB],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: emberRing ? Tone.ember.withValues(alpha: .28) : Tone.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .55),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap!, child: card);
  }
}

/// Staggered entrance: gentle rise + fade, one section after another —
/// the calm cascade Apple uses instead of everything popping at once.
/// Animates once per mount; data reloads don't replay it.
class Reveal extends StatelessWidget {
  final Widget child;
  final int order;
  const Reveal({super.key, required this.child, this.order = 0});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delayMs = 55 * order;
    final totalMs = 480 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Scale-on-press wrapper (the `.press`/`:active` feel of the web version).
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const Pressable({super.key, required this.child, required this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .965 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Tone.easeOut,
        child: widget.child,
      ),
    );
  }
}

enum PillStyle { ember, glass, quiet }

class Pill extends StatelessWidget {
  final String label;
  final PillStyle style;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expanded;

  const Pill(
    this.label, {
    super.key,
    this.style = PillStyle.glass,
    this.icon,
    this.onTap,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = switch (style) {
      PillStyle.ember => Tone.emberInk,
      PillStyle.glass => Tone.ink,
      PillStyle.quiet => Tone.ink2,
    };
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: style == PillStyle.quiet
                ? FontWeight.w600
                : FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    );
    final box = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : .4,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tone.rPill),
          gradient: style == PillStyle.ember
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF6B26E), Color(0xFFE7994C)],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Tone.glassA, Tone.glassB],
                ),
          border: style == PillStyle.ember
              ? null
              : Border.all(color: Tone.line),
          boxShadow: style == PillStyle.ember
              ? [
                  BoxShadow(
                    color: Tone.ember.withValues(alpha: .25),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Center(child: content),
      ),
    );
    final sized = expanded ? SizedBox(width: double.infinity, child: box) : box;
    if (!enabled) return sized;
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: sized,
    );
  }
}

/// The circular check used for tasks (ember-filled when done).
/// Visual size 27px, hit target 44px (a11y minimum).
class CheckCircle extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  final String semanticLabel;
  const CheckCircle({
    super.key,
    required this.on,
    required this.onTap,
    this.semanticLabel = 'علامتِ انجام',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      checked: on,
      button: true,
      child: Pressable(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(width: 44, height: 44, child: Center(child: _circle())),
      ),
    );
  }

  Widget _circle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Tone.easeOut,
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: on
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF6B26E), Color(0xFFE7994C)],
              )
            : null,
        border: on
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: .22),
                width: 1.5,
              ),
        boxShadow: on
            ? [
                BoxShadow(
                  color: Tone.ember.withValues(alpha: .3),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: on
          ? const Icon(Icons.check_rounded, size: 16, color: Tone.emberInk)
          : null,
    );
  }
}

/// Bottom sheet with the glass grab-handle look.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .88,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF17171B), Color(0xFF0C0C0F)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Tone.line),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(top: 14, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Flexible(child: builder(ctx)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Sheet header: title + optional subtitle, matching the web version.
class SheetHeader extends StatelessWidget {
  final String title;
  final String? sub;
  const SheetHeader(this.title, {super.key, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: TextStyle(fontSize: 12.5, color: Tone.ink2, height: 1.9),
            ),
          ],
        ],
      ),
    );
  }
}

/// Text field styled like the web `.input`.
class GlassField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final String? label;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const GlassField({
    super.key,
    this.controller,
    required this.hint,
    this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final field = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tone.line),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        autofocus: autofocus,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Tone.ink3, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
        ),
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label!,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Tone.ink3,
            ),
          ),
        ),
        const SizedBox(height: 7),
        field,
      ],
    );
  }
}

/// Small top toast, like the web version. Pass [actionLabel]/[onAction] for
/// an inline action (e.g. «برگردان» to undo a delete).
void showToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  var handled = false;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.paddingOf(ctx).top + 14,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Tone.easeOut,
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, (1 - v) * -24),
                child: child,
              ),
            ),
            child: Container(
              padding: EdgeInsetsDirectional.only(
                start: 20,
                end: actionLabel == null ? 20 : 8,
                top: actionLabel == null ? 12 : 7,
                bottom: actionLabel == null ? 12 : 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C21),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Tone.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    message,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Tone.ink,
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: 10),
                    Pressable(
                      onTap: () {
                        if (handled) return;
                        handled = true;
                        if (entry.mounted) entry.remove();
                        onAction?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Tone.emberSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          actionLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Tone.ember,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(Duration(milliseconds: actionLabel == null ? 2200 : 5000), () {
    if (entry.mounted) entry.remove();
  });
}

/// iOS-style wheel time picker in a glass sheet.
/// Returns minutes-of-day, or null when dismissed.
Future<int?> showWheelTimePicker(
  BuildContext context, {
  required int initialMinutes,
  String title = 'انتخاب ساعت',
  String? sub,
}) async {
  var selected = initialMinutes;
  final ok = await showGlassSheet<bool>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title, sub: sub),
          SizedBox(
            height: 190,
            child: CupertinoTheme(
              data: const CupertinoThemeData(
                brightness: Brightness.dark,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 21,
                    color: Tone.ink,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(
                  2026,
                  1,
                  1,
                  initialMinutes ~/ 60,
                  initialMinutes % 60,
                ),
                onDateTimeChanged: (d) => selected = d.hour * 60 + d.minute,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Pill(
              'تنظیم',
              style: PillStyle.ember,
              onTap: () => Navigator.pop(ctx, true),
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true ? selected : null;
}

/// Human-readable failure state instead of a raw exception dump.
class ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const ErrorCard({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 34, color: Tone.ink3),
            const SizedBox(height: 14),
            const Text(
              'مشکلی پیش آمد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'داده‌هایت سر جایش است — فقط خواندنش خطا خورد.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Tone.ink3, height: 1.9),
            ),
            const SizedBox(height: 18),
            Pill(
              'تلاش دوباره',
              style: PillStyle.ember,
              expanded: false,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-button confirm sheet, optionally with a one-line input.
/// Resolves to (confirmed, inputText).
Future<(bool, String?)> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? sub,
  String yesLabel = 'باشه',
  String noLabel = 'انصراف',
  bool withInput = false,
  String inputHint = 'یک خط…',
  bool emberYes = true,
}) async {
  final controller = TextEditingController();
  final result = await showGlassSheet<bool>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title, sub: sub),
          if (withInput)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GlassField(controller: controller, hint: inputHint),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Pill(
                    noLabel,
                    style: PillStyle.quiet,
                    onTap: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pill(
                    yesLabel,
                    style: emberYes ? PillStyle.ember : PillStyle.glass,
                    onTap: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  final text = controller.text.trim();
  controller.dispose();
  return (result ?? false, text.isEmpty ? null : text);
}
