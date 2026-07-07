import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Long-press a task → fix a typo or drop it, without replanning the whole
/// day. Deleting the boulder hands the crown to the next task.
Future<void> openTaskEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required String taskId,
  required String title,
  required bool isBoulder,
}) {
  return showGlassSheet(
    context,
    builder: (_) =>
        _TaskEditSheet(taskId: taskId, title: title, isBoulder: isBoulder),
  );
}

class _TaskEditSheet extends ConsumerStatefulWidget {
  final String taskId;
  final String title;
  final bool isBoulder;
  const _TaskEditSheet({
    required this.taskId,
    required this.title,
    required this.isBoulder,
  });

  @override
  ConsumerState<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<_TaskEditSheet> {
  late final _controller = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) {
      showToast(context, 'عنوان خالی نمی‌شود');
      return;
    }
    if (title != widget.title) {
      await ref.read(todayProvider.notifier).renameTask(widget.taskId, title);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final (yes, _) = await showConfirmSheet(
      context,
      title: widget.isBoulder ? 'تخته‌سنگ حذف شود؟' : 'این کار حذف شود؟',
      sub: widget.isBoulder
          ? 'کارِ بعدی، تخته‌سنگِ امروز می‌شود.'
          : 'از برنامهٔ امروز برداشته می‌شود.',
      yesLabel: 'حذف',
      emberYes: false,
    );
    if (!yes || !mounted) return;
    await ref.read(todayProvider.notifier).removeTask(widget.taskId);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, 'حذف شد');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(widget.isBoulder ? 'تخته‌سنگ' : 'ویرایش کار'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: GlassField(
              controller: _controller,
              hint: 'عنوان کار…',
              autofocus: true,
              onSubmitted: (_) => _save(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Pill('حذف', style: PillStyle.quiet, onTap: _delete),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Pill('ذخیره', style: PillStyle.ember, onTap: _save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
