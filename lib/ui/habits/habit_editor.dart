import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fa.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Anchor-based habit editor: after [everyday event], [tiny behavior].
/// Bad habits get a long-term cost and a one-tap replacement instead.
Future<void> openHabitEditor(BuildContext context, {Habit? habit}) {
  return showGlassSheet(context, builder: (_) => _HabitEditor(habit: habit));
}

class _HabitEditor extends ConsumerStatefulWidget {
  final Habit? habit;
  const _HabitEditor({this.habit});

  @override
  ConsumerState<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<_HabitEditor> {
  late final _cue = TextEditingController(text: widget.habit?.cue ?? '');
  late final _title = TextEditingController(text: widget.habit?.title ?? '');
  late final _cost = TextEditingController(text: widget.habit?.badCost ?? '');
  late final _replacement = TextEditingController(
    text: widget.habit?.replacement ?? '',
  );
  late bool _isBad = widget.habit?.isBad ?? false;
  late int? _reminderMinutes = widget.habit?.reminderMinutes;

  @override
  void dispose() {
    _cue.dispose();
    _title.dispose();
    _cost.dispose();
    _replacement.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showWheelTimePicker(
      context,
      initialMinutes: _reminderMinutes ?? 8 * 60,
      title: 'ساعتِ یادآور',
      sub: 'همان لحظه‌ای که لنگر اتفاق می‌افتد.',
    );
    if (picked != null && mounted) {
      setState(() => _reminderMinutes = picked);
    }
  }

  Future<void> _save() async {
    final cue = _cue.text.trim();
    final title = _title.text.trim();
    if (cue.isEmpty || title.isEmpty) {
      showToast(context, 'هر دو خانه لازم است — لنگر، نصفِ عادت است');
      return;
    }
    if (_isBad && _cost.text.trim().isEmpty) {
      showToast(context, 'هزینهٔ بلندمدت را بنویس — سلاحِ لحظهٔ وسوسه است');
      return;
    }
    await ref
        .read(habitsProvider.notifier)
        .save(
          id: widget.habit?.id,
          title: title,
          cue: cue,
          isBad: _isBad,
          badCost: _isBad ? _cost.text.trim() : '',
          replacement: _isBad ? _replacement.text.trim() : '',
          reminderMinutes: _reminderMinutes,
        );
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, widget.habit == null ? 'عادت ساخته شد' : 'ذخیره شد');
  }

  Future<void> _delete() async {
    final habit = widget.habit;
    if (habit == null) return;
    final (yes, _) = await showConfirmSheet(
      context,
      title: 'حذف عادت؟',
      sub: 'تاریخچه‌اش هم پاک می‌شود.',
      yesLabel: 'حذف',
    );
    if (!yes || !mounted) return;
    await ref.read(habitsProvider.notifier).remove(habit.id);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, 'عادت حذف شد');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          widget.habit == null ? 'عادت جدید' : 'ویرایش عادت',
          sub: _isBad
              ? 'همان محرک، پاسخ جدید. جایگزینی، تنها راهِ ترکِ پایدار است.'
              : 'عادت بدون لنگر شکست می‌خورد. فرمول: بعد از [رویدادِ همیشگی]، [رفتار کوچک].',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            children: [
              _typeSwitch(),
              const SizedBox(height: 12),
              GlassField(
                controller: _cue,
                label: 'بعد از…',
                hint: 'مثلاً: قهوهٔ صبح',
              ),
              const SizedBox(height: 12),
              GlassField(
                controller: _title,
                label: _isBad
                    ? 'عادت بد (رفتاری که تکرار می‌شود)'
                    : 'این کار را می‌کنم',
                hint: _isBad
                    ? 'مثلاً: چک کردن اینستاگرام'
                    : 'مثلاً: ۱۰ دقیقه ورزش',
              ),
              if (_isBad) ...[
                const SizedBox(height: 12),
                GlassField(
                  controller: _cost,
                  label: 'هزینهٔ بلندمدت (لحظهٔ وسوسه نشان داده می‌شود)',
                  hint: 'اگر یک سال ادامه‌اش دهم…',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                GlassField(
                  controller: _replacement,
                  label: 'به‌جایش این کار را می‌کنم',
                  hint: 'مثلاً: دو دقیقه قدم می‌زنم',
                ),
              ],
              const SizedBox(height: 12),
              _reminderRow(),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Row(
            children: [
              if (widget.habit != null) ...[
                Expanded(
                  child: Pill('حذف', style: PillStyle.quiet, onTap: _delete),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: Pill('ذخیره', style: PillStyle.ember, onTap: _save),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeSwitch() {
    Widget cell(String label, bool bad) {
      final on = _isBad == bad;
      return Expanded(
        child: Pressable(
          onTap: () => setState(() => _isBad = bad),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: on
                  ? (bad ? Tone.warn.withValues(alpha: .12) : Tone.emberSoft)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: on
                    ? (bad
                          ? Tone.warn.withValues(alpha: .35)
                          : Tone.ember.withValues(alpha: .3))
                    : Tone.line,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: on ? (bad ? Tone.warn : Tone.ember) : Tone.ink3,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        cell('ساختن عادت', false),
        const SizedBox(width: 8),
        cell('ترک عادت', true),
      ],
    );
  }

  Widget _reminderRow() {
    final m = _reminderMinutes;
    final label = m == null
        ? 'بدون یادآور'
        : faNum(
            '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
          );
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      onTap: _pickTime,
      child: Row(
        children: [
          Icon(Icons.notifications_none_rounded, size: 18, color: Tone.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'یادآور در زمانِ محرک',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  'هر روز، همان لحظه‌ای که لنگر اتفاق می‌افتد',
                  style: TextStyle(fontSize: 11, color: Tone.ink3),
                ),
              ],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: m == null ? Tone.ink3 : Tone.ember,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (m != null)
            Pressable(
              onTap: () => setState(() => _reminderMinutes = null),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.close_rounded, size: 15, color: Tone.warn),
              ),
            ),
        ],
      ),
    );
  }
}
