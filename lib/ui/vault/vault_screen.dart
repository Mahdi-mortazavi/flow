import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Dedicated full-screen Brain Vault: quick capture, categorize, search,
/// and promote thoughts into tasks.
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _input = TextEditingController();
  final _search = TextEditingController();
  var _category = ThoughtCategory.idea;
  ThoughtCategory? _selectedFilter;
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
    ref.watch(accentProvider);
    final lang = ref.watch(appLanguageProvider);
    final thoughtsAsync = ref.watch(thoughtsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const _Ambient(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: thoughtsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => ErrorCard(
                    onRetry: () => ref.invalidate(thoughtsProvider),
                  ),
                  data: (all) => _buildBody(all, lang),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Thought> all, AppLanguage lang) {
    final filtered = all.where((t) {
      if (_selectedFilter != null && t.category != _selectedFilter) {
        return false;
      }
      if (_query.isNotEmpty &&
          !t.text.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
      children: [
        Reveal(child: _Header(lang: lang)),
        const SizedBox(height: 16),
        Reveal(
          order: 1,
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final c in ThoughtCategory.values) ...[
                      Expanded(child: _catChip(c, lang)),
                      if (c != ThoughtCategory.values.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (all.isNotEmpty) ...[
          Reveal(
            order: 2,
            child: Row(
              children: [
                Expanded(
                  child: GlassField(
                    controller: _search,
                    hint: L10n.searchHint(lang),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Reveal(
            order: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(null, lang == AppLanguage.fa ? 'همه' : 'All'),
                  const SizedBox(width: 6),
                  for (final c in ThoughtCategory.values) ...[
                    _filterChip(c, _localizedCategoryLabel(c, lang)),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (filtered.isEmpty)
          Reveal(
            order: 3,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Tone.accent.withValues(alpha: .12),
                      border: Border.all(
                        color: Tone.accent.withValues(alpha: .3),
                      ),
                    ),
                    child: Icon(
                      Icons.psychology_outlined,
                      size: 28,
                      color: Tone.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _query.isEmpty && _selectedFilter == null
                        ? L10n.brainVaultTitle(lang)
                        : L10n.noResultsFound(lang),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _query.isEmpty && _selectedFilter == null
                        ? (lang == AppLanguage.fa
                              ? 'ذهن برای ایده‌پردازی است، نه نگه‌داشتن آنها. هر فکر، کار یا نگرانی را اینجا خالی کن.'
                              : 'Your mind is for having ideas, not holding them. Capture any thought or worry here.')
                        : (lang == AppLanguage.fa
                              ? 'موردی با این مشخصات پیدا نشد.'
                              : 'No thoughts match this filter.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Tone.ink3,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < filtered.length; i++)
            Reveal(
              order: 3 + (i > 5 ? 5 : i),
              child: _thoughtCard(filtered[i], lang),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _filterChip(ThoughtCategory? category, String label) {
    final selected = _selectedFilter == category;
    return Pressable(
      onTap: () => setState(() => _selectedFilter = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Tone.accent.withValues(alpha: .15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Tone.accent.withValues(alpha: .4) : Tone.line,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Tone.accent : Tone.ink3,
          ),
        ),
      ),
    );
  }

  Widget _thoughtCard(Thought t, AppLanguage lang) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                    color: Colors.white.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Tone.line),
                  ),
                  child: Text(
                    _localizedCategoryLabel(t.category, lang),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Tone.ink2,
                    ),
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
            Text(t.text, style: const TextStyle(fontSize: 14.5, height: 1.7)),
            const SizedBox(height: 12),
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
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: Tone.accent.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Tone.accent.withValues(alpha: .15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_circle_up_rounded,
                      size: 15,
                      color: Tone.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang == AppLanguage.fa
                          ? 'ارتقا به کار'
                          : 'Promote to Task',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Tone.accent,
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

  Widget _tinyBtn(IconData icon, AppLanguage lang, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: icon == Icons.close_rounded
            ? L10n.delete(lang)
            : L10n.edit(lang),
        child: Pressable(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: Icon(icon, size: 16, color: Tone.ink3)),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final AppLanguage lang;
  const _Header({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.brainVaultTitle(lang),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            L10n.brainVaultSub(lang),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Tone.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ambient extends StatelessWidget {
  const _Ambient();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.9),
              radius: 1.2,
              colors: [Tone.accent.withValues(alpha: .07), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}
