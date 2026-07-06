import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (mounted) showToast(context, 'فکر ثبت شد');
  }

  @override
  Widget build(BuildContext context) {
    final thoughtsAsync = ref.watch(thoughtsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(
          'مخزنِ ذهن',
          sub: 'هر چه ذهن را سنگین می‌کند، اینجا بگذار. هیچ چیز گم نمی‌شود.',
        ),
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
                          ? 'فکر یا ایده‌ات را بنویس…'
                          : 'ویرایش فکر…',
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pill(
                    _editingId == null ? 'ثبت' : 'ذخیره',
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
                    Expanded(child: _catChip(c)),
                    if (c != ThoughtCategory.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              GlassField(
                controller: _search,
                hint: 'جستجو…',
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
                        ? 'هنوز فکری ثبت نشده.'
                        : 'نتیجه‌ای یافت نشد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Tone.ink3),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _thoughtCard(list[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _catChip(ThoughtCategory c) {
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
            c.label,
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

  Widget _thoughtCard(Thought t) {
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
                    t.category.label,
                    style: TextStyle(fontSize: 10, color: Tone.ink2),
                  ),
                ),
                const Spacer(),
                _tinyBtn(Icons.edit_rounded, () {
                  setState(() {
                    _editingId = t.id;
                    _input.text = t.text;
                    _category = t.category;
                  });
                }),
                const SizedBox(width: 4),
                _tinyBtn(Icons.close_rounded, () async {
                  await ref.read(thoughtsProvider.notifier).remove(t.id);
                  if (mounted) showToast(context, 'حذف شد');
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
                      ? 'به کارهای امروز اضافه شد'
                      : 'برای ویزارد فردا ذخیره شد',
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
                      'ارتقا به کار',
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

  Widget _tinyBtn(IconData icon, VoidCallback onTap) => Pressable(
    onTap: onTap,
    child: SizedBox(
      width: 30,
      height: 30,
      child: Icon(icon, size: 14, color: Tone.ink3),
    ),
  );
}
