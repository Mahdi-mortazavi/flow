import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
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

  Future<void> _pickTime(AppLanguage lang) async {
    final picked = await showWheelTimePicker(
      context,
      initialMinutes: _reminderMinutes ?? 8 * 60,
      title: lang == AppLanguage.fa ? 'ساعتِ یادآور' : 'Reminder Time',
      sub: lang == AppLanguage.fa
          ? 'همان لحظه‌ای که لنگر اتفاق می‌افتد.'
          : 'The exact moment the anchor cue happens.',
    );
    if (picked != null && mounted) {
      setState(() => _reminderMinutes = picked);
    }
  }

  Future<void> _save() async {
    final lang = ref.read(appLanguageProvider);
    final cue = _cue.text.trim();
    final title = _title.text.trim();
    if (cue.isEmpty || title.isEmpty) {
      showToast(
        context,
        lang == AppLanguage.fa
            ? 'هر دو خانه لازم است — لنگر، نصفِ عادت است'
            : 'Both fields required — the cue is half the habit',
      );
      return;
    }
    if (_isBad && _cost.text.trim().isEmpty) {
      showToast(
        context,
        lang == AppLanguage.fa
            ? 'هزینهٔ بلندمدت را بنویس — سلاحِ لحظهٔ وسوسه است'
            : 'Write the long-term cost — it is your weapon when tempted',
      );
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
    showToast(
      context,
      widget.habit == null
          ? (lang == AppLanguage.fa ? 'عادت ساخته شد' : 'Habit created')
          : (lang == AppLanguage.fa ? 'ذخیره شد' : 'Saved'),
    );
  }

  Future<void> _delete() async {
    final lang = ref.read(appLanguageProvider);
    final habit = widget.habit;
    if (habit == null) return;
    final (yes, _) = await showConfirmSheet(
      context,
      title: lang == AppLanguage.fa ? 'حذف عادت؟' : 'Delete habit?',
      sub: lang == AppLanguage.fa
          ? 'تاریخچه‌اش هم پاک می‌شود.'
          : 'Its history will also be cleared.',
      yesLabel: L10n.delete(lang),
      noLabel: L10n.cancel(lang),
    );
    if (!yes || !mounted) return;
    await ref.read(habitsProvider.notifier).remove(habit.id);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(
      context,
      lang == AppLanguage.fa ? 'عادت حذف شد' : 'Habit deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          widget.habit == null
              ? L10n.newHabitTitle(lang)
              : L10n.editHabitTitle(lang),
          sub: _isBad
              ? (lang == AppLanguage.fa
                    ? 'همان محرک، پاسخ جدید. جایگزینی، تنها راهِ ترکِ پایدار است.'
                    : 'Same cue, new response. Replacement is the only path to lasting habit change.')
              : (lang == AppLanguage.fa
                    ? 'عادت بدون لنگر شکست می‌خورد. فرمول: بعد از [رویدادِ همیشگی]، [رفتار کوچک].'
                    : 'Habits fail without an anchor. Formula: After [routine event], [tiny behavior].'),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            children: [
              _typeSwitch(lang),
              const SizedBox(height: 12),
              GlassField(
                controller: _cue,
                label: lang == AppLanguage.fa ? 'بعد از…' : 'After...',
                hint: L10n.cueHint(lang),
              ),
              const SizedBox(height: 12),
              GlassField(
                controller: _title,
                label: _isBad
                    ? (lang == AppLanguage.fa
                          ? 'عادت بد (رفتاری که تکرار می‌شود)'
                          : 'Bad habit (repeating behavior)')
                    : (lang == AppLanguage.fa
                          ? 'این کار را می‌کنم'
                          : 'I will do this'),
                hint: _isBad
                    ? (lang == AppLanguage.fa
                          ? 'مثلاً: چک کردن اینستاگرام'
                          : 'e.g., Checking Instagram')
                    : L10n.habitTitleHint(lang),
              ),
              if (_isBad) ...[
                const SizedBox(height: 12),
                GlassField(
                  controller: _cost,
                  label: lang == AppLanguage.fa
                      ? 'هزینهٔ بلندمدت (لحظهٔ وسوسه نشان داده می‌شود)'
                      : 'Long-term cost (shown when tempted)',
                  hint: lang == AppLanguage.fa
                      ? 'اگر یک سال ادامه‌اش دهم…'
                      : 'If I keep doing this for a year...',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                GlassField(
                  controller: _replacement,
                  label: L10n.replacementInputLabel(lang),
                  hint: L10n.replacementInputHint(lang),
                ),
              ],
              const SizedBox(height: 12),
              _reminderRow(lang),
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
                  child: Pill(
                    L10n.delete(lang),
                    style: PillStyle.quiet,
                    onTap: _delete,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: Pill(
                  L10n.save(lang),
                  style: PillStyle.ember,
                  onTap: _save,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeSwitch(AppLanguage lang) {
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
        cell(lang == AppLanguage.fa ? 'ساختن عادت' : 'Build Habit', false),
        const SizedBox(width: 8),
        cell(lang == AppLanguage.fa ? 'ترک عادت' : 'Break Habit', true),
      ],
    );
  }

  Widget _reminderRow(AppLanguage lang) {
    final m = _reminderMinutes;
    final label = m == null
        ? (lang == AppLanguage.fa ? 'بدون یادآور' : 'No reminder')
        : L10n.fmtNum(
            '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
            lang,
          );
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      onTap: () => _pickTime(lang),
      child: Row(
        children: [
          Icon(Icons.notifications_none_rounded, size: 18, color: Tone.ink2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == AppLanguage.fa
                      ? 'یادآور در زمانِ محرک'
                      : 'Reminder at cue time',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  lang == AppLanguage.fa
                      ? 'هر روز، همان لحظه‌ای که لنگر اتفاق می‌افتد'
                      : 'Every day, right when the anchor happens',
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
