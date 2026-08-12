import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// The 60-second morning ritual: pick ≤3 tasks, star the boulder, predict.
Future<void> openMorningWizard(BuildContext context, WidgetRef ref) {
  return showGlassSheet(context, builder: (_) => const _MorningWizard());
}

class _MorningWizard extends ConsumerStatefulWidget {
  const _MorningWizard();

  @override
  ConsumerState<_MorningWizard> createState() => _MorningWizardState();
}

class _MorningWizardState extends ConsumerState<_MorningWizard> {
  List<BacklogItem>? _backlog;
  final _selected = <String>[];
  String? _boulderId;
  double _prediction = 70;
  final _newTask = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    final backlog = await repo.backlog();
    final plan = await ref.read(todayProvider.future);
    // Replan case: make sure today's tasks are selectable and pre-selected.
    final ids = backlog.map((b) => b.id).toSet();
    for (final t in plan.tasks) {
      if (!ids.contains(t.taskId)) {
        backlog.insert(0, BacklogItem(id: t.taskId, title: t.title));
      }
    }
    setState(() {
      _backlog = backlog;
      if (plan.planned) {
        _selected.addAll(plan.tasks.map((t) => t.taskId));
        _boulderId = plan.boulderId;
        _prediction = (plan.prediction ?? 70).toDouble();
      }
    });
  }

  void _toggle(String id, AppLanguage lang) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_boulderId == id) _boulderId = null;
      } else {
        if (_selected.length >= 3) {
          showToast(
            context,
            lang == AppLanguage.fa
                ? 'حداکثر ۳ کار — این خودِ روش است'
                : 'Max 3 tasks — this is the essence of the system',
          );
          return;
        }
        _selected.add(id);
        _boulderId ??= id;
      }
    });
  }

  Future<void> _addNew(String value) async {
    final title = value.trim();
    if (title.isEmpty) return;
    final item = await ref.read(repoProvider).addBacklog(title);
    setState(() {
      _backlog = [item, ...?_backlog];
      if (_selected.length < 3) {
        _selected.add(item.id);
        _boulderId ??= item.id;
      }
      _newTask.clear();
    });
  }

  Future<void> _go(AppLanguage lang) async {
    final backlog = _backlog;
    final boulderId = _boulderId;
    if (backlog == null || boulderId == null || _selected.isEmpty) return;
    final selected = [
      for (final id in _selected) backlog.firstWhere((b) => b.id == id),
    ];
    await ref
        .read(todayProvider.notifier)
        .plan(
          selected: selected,
          boulderId: boulderId,
          prediction: _prediction.round(),
        );
    if (!mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    Navigator.pop(context);
    showToast(context, L10n.dayPlannedToast(lang));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    final backlog = _backlog;
    final ready = _selected.isNotEmpty && _boulderId != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          L10n.morningPlanHeader(lang),
          sub: L10n.morningPlanSub(lang),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            children: [
              if (backlog == null)
                const SizedBox(height: 60)
              else if (backlog.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    lang == AppLanguage.fa
                        ? 'لیستِ کارها خالی است. اولین کارِ مهم را بنویس ↓'
                        : 'Task list is empty. Write your first important task ↓',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Tone.ink3),
                  ),
                )
              else
                for (final b in backlog) _row(b, lang),
              const SizedBox(height: 14),
              GlassField(
                controller: _newTask,
                hint: L10n.newTaskHint(lang),
                onSubmitted: _addNew,
              ),
              if (_boulderId != null) _predictionBlock(lang),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Pill(
            L10n.startDay(lang),
            style: PillStyle.ember,
            onTap: ready ? () => _go(lang) : null,
          ),
        ),
      ],
    );
  }

  Widget _row(BacklogItem b, AppLanguage lang) {
    final on = _selected.contains(b.id);
    final star = _boulderId == b.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: () => _toggle(b.id, lang),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Tone.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: on
                ? Colors.white.withValues(alpha: .045)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: on
                  ? Colors.white.withValues(alpha: .14)
                  : Tone.line.withValues(alpha: .5),
            ),
          ),
          child: Row(
            children: [
              // selection ring
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 250),
                    curve: Tone.easeOut,
                    scale: on ? 1 : 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Tone.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  b.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (on)
                Pressable(
                  onTap: () => setState(() => _boulderId = b.id),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: star ? Tone.emberSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: star
                          ? Border.all(color: Tone.ember.withValues(alpha: .3))
                          : null,
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: star ? Tone.ember : Tone.ink3,
                    ),
                  ),
                )
              else
                Pressable(
                  onTap: () async {
                    await ref.read(repoProvider).deleteBacklog(b.id);
                    setState(
                      () => _backlog = _backlog
                          ?.where((x) => x.id != b.id)
                          .toList(),
                    );
                  },
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: Tone.ink3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _predictionBlock(AppLanguage lang) {
    return Column(
      children: [
        const SizedBox(height: 18),
        Text(
          L10n.boulderProbabilityQuestion(lang),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: Tone.ink3, height: 1.9),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L10n.fmtNum(_prediction.round(), lang),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w200,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  lang == AppLanguage.fa ? '٪' : '%',
                  style: TextStyle(fontSize: 16, color: Tone.ink3),
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: _prediction,
          min: 10,
          max: 95,
          divisions: 17,
          onChanged: (v) {
            if (v.round() != _prediction.round()) {
              HapticFeedback.selectionClick();
            }
            setState(() => _prediction = v);
          },
        ),
      ],
    );
  }
}
