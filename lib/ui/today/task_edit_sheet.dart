import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Long-press a task → fix a typo, set a reminder, or drop it, without
/// replanning the whole day. Deleting the boulder hands the crown to the next task.
Future<void> openTaskEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required String taskId,
  required String title,
  required bool isBoulder,
  int? reminderTime,
}) {
  return showGlassSheet(
    context,
    builder: (_) => _TaskEditSheet(
      taskId: taskId,
      title: title,
      isBoulder: isBoulder,
      reminderTime: reminderTime,
    ),
  );
}

class _TaskEditSheet extends ConsumerStatefulWidget {
  final String taskId;
  final String title;
  final bool isBoulder;
  final int? reminderTime;
  const _TaskEditSheet({
    required this.taskId,
    required this.title,
    required this.isBoulder,
    this.reminderTime,
  });

  @override
  ConsumerState<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<_TaskEditSheet> {
  late final _controller = TextEditingController(text: widget.title);
  late int? _reminderMinutes = widget.reminderTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime(AppLanguage lang) async {
    final now = DateTime.now();
    final initial = _reminderMinutes ?? (now.hour * 60 + now.minute);
    final picked = await showWheelTimePicker(
      context,
      initialMinutes: initial,
      title: L10n.setReminderTime(lang),
    );
    if (picked != null && mounted) {
      unawaited(HapticFeedback.selectionClick());
      setState(() => _reminderMinutes = picked);
    }
  }

  void _clearReminder() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _reminderMinutes = null);
  }

  Future<void> _save() async {
    final lang = ref.read(appLanguageProvider);
    final title = _controller.text.trim();
    if (title.isEmpty) {
      showToast(
        context,
        lang == AppLanguage.fa ? 'عنوان خالی نمی‌شود' : 'Title cannot be empty',
      );
      return;
    }
    if (title != widget.title) {
      await ref.read(todayProvider.notifier).renameTask(widget.taskId, title);
    }
    if (_reminderMinutes != widget.reminderTime) {
      await ref
          .read(todayProvider.notifier)
          .updateTaskReminder(widget.taskId, _reminderMinutes);
      if (mounted) {
        if (_reminderMinutes != null) {
          showToast(
            context,
            L10n.reminderSetToast(L10n.fmtTime(_reminderMinutes!, lang), lang),
          );
        } else {
          showToast(context, L10n.reminderClearedToast(lang));
        }
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final lang = ref.read(appLanguageProvider);
    final (yes, _) = await showConfirmSheet(
      context,
      title: widget.isBoulder
          ? (lang == AppLanguage.fa
                ? 'تخته‌سنگ حذف شود؟'
                : 'Delete The Boulder?')
          : (lang == AppLanguage.fa ? 'این کار حذف شود؟' : 'Delete this task?'),
      sub: widget.isBoulder
          ? (lang == AppLanguage.fa
                ? 'کارِ بعدی، تخته‌سنگِ امروز می‌شود.'
                : 'The next task will become today\'s Boulder.')
          : (lang == AppLanguage.fa
                ? 'از برنامهٔ امروز برداشته می‌شود.'
                : 'Will be removed from today\'s plan.'),
      yesLabel: L10n.delete(lang),
      noLabel: L10n.cancel(lang),
      emberYes: false,
    );
    if (!yes || !mounted) return;
    await ref.read(todayProvider.notifier).removeTask(widget.taskId);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, lang == AppLanguage.fa ? 'حذف شد' : 'Deleted');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accentProvider);
    final lang = ref.watch(appLanguageProvider);
    final hasReminder = _reminderMinutes != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            widget.isBoulder ? L10n.theBoulder(lang) : L10n.editTaskTitle(lang),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: GlassField(
              controller: _controller,
              hint: lang == AppLanguage.fa ? 'عنوان کار…' : 'Task title...',
              autofocus: true,
              onSubmitted: (_) => _save(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Tone.glassA,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasReminder ? Tone.accent.withAlpha(80) : Tone.line,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pickReminderTime(lang),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasReminder
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          size: 19,
                          color: hasReminder ? Tone.accent : Tone.ink2,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hasReminder
                                ? L10n.reminderTimeLabel(
                                    L10n.fmtTime(_reminderMinutes!, lang),
                                    lang,
                                  )
                                : L10n.setReminderTime(lang),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: hasReminder ? Tone.ink : Tone.ink2,
                              fontWeight: hasReminder
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasReminder)
                          GestureDetector(
                            onTap: _clearReminder,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 17,
                                color: Tone.ink2,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 19,
                            color: Tone.ink2,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Pill(
                    L10n.delete(lang),
                    style: PillStyle.quiet,
                    onTap: _delete,
                  ),
                ),
                const SizedBox(width: 10),
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
      ),
    );
  }
}
