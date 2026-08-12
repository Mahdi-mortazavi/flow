import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// The brain vault: dump any thought in two seconds, so the head stays clear.
Future<void> openVaultSheet(BuildContext context) {
  return showGlassSheet(context, builder: (_) => const _VaultSheet());
}

class _VaultSheet extends ConsumerStatefulWidget {
  const _VaultSheet();

  @override
  ConsumerState<_VaultSheet> createState() => _VaultSheetState();
}

class _VaultSheetState extends ConsumerState<_VaultSheet> {
  final _input = TextEditingController();
  final _search = TextEditingController();
  var _category = ThoughtCategory.idea;
  String? _editingId;
  var _query = '';

  @override
  void dispose() {
    _input.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = ref.read(appLanguageProvider);
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final n = ref.read(thoughtsProvider.notifier);
    if (_editingId != null) {
      await n.updateThought(_editingId!, text, _category);
    } else {
      await n.add(text, _category);
    }
    setState(() {
      _input.clear();
      _editingId = null;
    });
    if (mounted) {
      showToast(
        context,
        lang == AppLanguage.fa ? 'فکر ثبت شد' : 'Thought recorded',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final thoughtsAsync = ref.watch(thoughtsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(L10n.brainVaultTitle(lang), sub: L10n.brainVaultSub(lang)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: GlassField(
                      controller: _input,
                      hint: _editingId == null
                          ? L10n.thoughtHint(lang)
                          : (lang == AppLanguage.fa
                                ? 'ویرایش فکر…'
                                : 'Edit thought...'),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pill(
                    _editingId == null
                        ? (lang == AppLanguage.fa ? 'ثبت' : 'Save')
                        : L10n.save(lang),
                    style: PillStyle.ember,
                    expanded: false,
                    onTap: _submit,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in ThoughtCategory.values) ...[
                    Expanded(child: _catChip(c, lang)),
                    if (c != ThoughtCategory.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              GlassField(
                controller: _search,
                hint: L10n.searchHint(lang),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ],
          ),
        ),
        Flexible(
          child: thoughtsAsync.when(
            loading: () => const SizedBox(height: 100),
            error: (e, _) =>
                SizedBox(height: 100, child: Center(child: Text('$e'))),
            data: (all) {
              final list = _query.isEmpty
                  ? all
                  : all.where((t) => t.text.contains(_query)).toList();
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    _query.isEmpty
                        ? (lang == AppLanguage.fa
                              ? 'هنوز فکری ثبت نشده.'
                              : 'No thoughts recorded yet.')
                        : L10n.noResultsFound(lang),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Tone.ink3),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _thoughtCard(list[i], lang),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _catChip(ThoughtCategory c, AppLanguage lang) {
    final on = _category == c;
    return Pressable(
      onTap: () => setState(() => _category = c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: on ? Tone.emberSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? Tone.ember.withValues(alpha: .3) : Tone.line,
          ),
        ),
        child: Center(
          child: Text(
            _localizedCategoryLabel(c, lang),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: on ? Tone.ember : Tone.ink3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _thoughtCard(Thought t, AppLanguage lang) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _localizedCategoryLabel(t.category, lang),
                    style: TextStyle(fontSize: 10, color: Tone.ink2),
                  ),
                ),
                const Spacer(),
                _tinyBtn(Icons.edit_rounded, lang, () {
                  setState(() {
                    _editingId = t.id;
                    _input.text = t.text;
                    _category = t.category;
                  });
                }),
                const SizedBox(width: 4),
                _tinyBtn(Icons.close_rounded, lang, () async {
                  final n = ref.read(thoughtsProvider.notifier);
                  await n.remove(t.id);
                  if (!mounted) return;
                  // Nothing is ever lost: 5 seconds to change your mind.
                  showToast(
                    context,
                    lang == AppLanguage.fa ? 'حذف شد' : 'Deleted',
                    actionLabel: L10n.undo(lang),
                    onAction: () => n.restore(t),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.text, style: const TextStyle(fontSize: 14, height: 1.8)),
            const SizedBox(height: 10),
            Pressable(
              onTap: () async {
                final onToday = await ref
                    .read(thoughtsProvider.notifier)
                    .promote(t);
                if (!mounted) return;
                showToast(
                  context,
                  onToday
                      ? (lang == AppLanguage.fa
                            ? 'به کارهای امروز اضافه شد'
                            : 'Added to today\'s tasks')
                      : (lang == AppLanguage.fa
                            ? 'برای ویزارد فردا ذخیره شد'
                            : 'Saved for tomorrow\'s wizard'),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Tone.ember.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Tone.ember.withValues(alpha: .10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_circle_up_rounded,
                      size: 14,
                      color: Tone.ember.withValues(alpha: .7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang == AppLanguage.fa
                          ? 'ارتقا به کار'
                          : 'Promote to Task',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Tone.ember.withValues(alpha: .7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedCategoryLabel(ThoughtCategory c, AppLanguage lang) {
    if (lang == AppLanguage.fa) return c.label;
    return switch (c) {
      ThoughtCategory.idea => 'Idea',
      ThoughtCategory.worry => 'Worry',
      ThoughtCategory.sideTask => 'Side Task',
    };
  }

  // 44px hit target around a small glyph (a11y minimum).
  Widget _tinyBtn(IconData icon, AppLanguage lang, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: icon == Icons.close_rounded
            ? L10n.delete(lang)
            : L10n.edit(lang),
        child: Pressable(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 14, color: Tone.ink3),
          ),
        ),
      );
}
