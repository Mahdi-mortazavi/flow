import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fa.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/repo.dart';
import '../../state/providers.dart';
import '../widgets/glass.dart';

/// Reminders, backup and reliability — the boring things that keep the
/// daily ritual alive.
Future<void> openSettingsSheet(BuildContext context) {
  return showGlassSheet(context, builder: (_) => const _SettingsSheet());
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  int? _morning;
  int? _evening;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(repoProvider);
    final m = await repo.reminderMinutes('rem_morning', Repo.defaultMorningMin);
    final e = await repo.reminderMinutes('rem_evening', Repo.defaultEveningMin);
    if (!mounted) return;
    setState(() {
      _morning = m;
      _evening = e;
      _loaded = true;
    });
  }

  Future<void> _saveReminder(String key, int? minutes) async {
    final repo = ref.read(repoProvider);
    await repo.setReminderMinutes(key, minutes);
    await syncDailyReminders(
      repo,
      ref.read(dayKeyProvider),
      ref.read(appLanguageProvider),
    );
  }

  Future<void> _export() async {
    final json = await ref.read(repoProvider).exportJson();
    final dir = await getTemporaryDirectory();
    final stamp = todayKey();
    final file = File('${dir.path}/flow-backup-$stamp.json');
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'پشتیبان تک‌نقطه — $stamp',
      ),
    );
  }

  Future<void> _import(AppLanguage lang) async {
    final picked = await FilePicker.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    final path = picked?.files.single.path;
    if (picked == null || (bytes == null && path == null)) return;
    if (!mounted) return;
    final (yes, _) = await showConfirmSheet(
      context,
      title: L10n.confirmRestoreTitle(lang),
      sub: L10n.confirmRestoreSub(lang),
      yesLabel: L10n.replaceAction(lang),
      emberYes: false,
    );
    if (!yes || !mounted) return;
    try {
      final raw = bytes != null
          ? utf8.decode(bytes)
          : await File(path!).readAsString();
      await ref.read(repoProvider).importJson(raw);
      ref
        ..invalidate(todayProvider)
        ..invalidate(habitsProvider)
        ..invalidate(thoughtsProvider)
        ..invalidate(funProvider)
        ..invalidate(statsProvider);
      await syncDailyReminders(
        ref.read(repoProvider),
        ref.read(dayKeyProvider),
        ref.read(appLanguageProvider),
      );
      if (mounted) showToast(context, L10n.restoreSuccess(lang));
    } on FormatException {
      if (mounted) showToast(context, L10n.invalidBackupFile(lang));
    }
  }

  Future<void> _openBatterySettings() async {
    if (!Platform.isAndroid) return;
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  String _fmt(int? m, AppLanguage lang) => m == null
      ? L10n.off(lang)
      : L10n.fmtNum(
          '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
          lang,
        );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 220);
    final appLang = ref.watch(appLanguageProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          L10n.settingsHeader(appLang),
          sub: L10n.settingsSub(appLang),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              _timeRow(
                icon: Icons.wb_twilight_rounded,
                title: L10n.morningReminder(appLang),
                sub: L10n.morningReminderSub(appLang),
                value: _morning,
                lang: appLang,
                onPick: () async {
                  final v = await showWheelTimePicker(
                    context,
                    initialMinutes: _morning ?? Repo.defaultMorningMin,
                    title: L10n.morningReminder(appLang),
                  );
                  if (v == null) return;
                  setState(() => _morning = v);
                  await _saveReminder('rem_morning', v);
                },
                onToggle: () async {
                  final next = _morning == null ? Repo.defaultMorningMin : null;
                  setState(() => _morning = next);
                  await _saveReminder('rem_morning', next);
                },
              ),
              const SizedBox(height: 9),
              _timeRow(
                icon: Icons.nightlight_round,
                title: L10n.eveningReminder(appLang),
                sub: L10n.eveningReminderSub(appLang),
                value: _evening,
                lang: appLang,
                onPick: () async {
                  final v = await showWheelTimePicker(
                    context,
                    initialMinutes: _evening ?? Repo.defaultEveningMin,
                    title: L10n.eveningReminder(appLang),
                  );
                  if (v == null) return;
                  setState(() => _evening = v);
                  await _saveReminder('rem_evening', v);
                },
                onToggle: () async {
                  final next = _evening == null ? Repo.defaultEveningMin : null;
                  setState(() => _evening = next);
                  await _saveReminder('rem_evening', next);
                },
              ),
              const SizedBox(height: 22),
              _actionRow(
                icon: Icons.ios_share_rounded,
                title: L10n.exportBackup(appLang),
                sub: L10n.exportBackupSub(appLang),
                onTap: _export,
              ),
              const SizedBox(height: 9),
              _actionRow(
                icon: Icons.settings_backup_restore_rounded,
                title: L10n.restoreBackup(appLang),
                sub: L10n.restoreBackupSub(appLang),
                onTap: () => _import(appLang),
              ),
              const SizedBox(height: 9),
              _actionRow(
                icon: Icons.language_rounded,
                title: L10n.appLanguage(appLang),
                sub: appLang == AppLanguage.fa ? 'فارسی' : 'English',
                onTap: () async {
                  await ref.read(appLanguageProvider.notifier).toggleLanguage();
                },
              ),
              const SizedBox(height: 22),
              _accentPicker(appLang),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 22),
                _actionRow(
                  icon: Icons.battery_alert_rounded,
                  title: L10n.batterySettings(appLang),
                  sub: L10n.batterySettingsSub(appLang),
                  onTap: _openBatterySettings,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _accentPicker(AppLanguage appLang) {
    final activeAccent = ref.watch(accentProvider);
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, size: 18, color: Tone.ink2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.accentColorTitle(appLang),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      L10n.accentColorSub(appLang),
                      style: TextStyle(fontSize: 11, color: Tone.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppAccent.values.map((accent) {
              final isSelected = accent == activeAccent;
              return Pressable(
                onTap: () {
                  ref.read(accentProvider.notifier).setAccent(accent);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.color.withValues(alpha: .18)
                        : Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(Tone.rPill),
                    border: Border.all(
                      color: isSelected
                          ? accent.color
                          : Colors.white.withValues(alpha: .10),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: accent.color,
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: accent.color.withValues(alpha: .5),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 10,
                                color: Colors.black87,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        accent.label(appLang),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? Tone.ink : Tone.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _timeRow({
    required IconData icon,
    required String title,
    required String sub,
    required int? value,
    required AppLanguage lang,
    required VoidCallback onPick,
    required VoidCallback onToggle,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      onTap: value == null ? onToggle : onPick,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Tone.ink2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(sub, style: TextStyle(fontSize: 11, color: Tone.ink3)),
              ],
            ),
          ),
          Text(
            _fmt(value, lang),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: value == null ? Tone.ink3 : Tone.ember,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Semantics(
            button: true,
            label: value == null ? L10n.turnOn(lang) : L10n.turnOff(lang),
            child: Pressable(
              onTap: onToggle,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  value == null
                      ? Icons.add_circle_outline_rounded
                      : Icons.close_rounded,
                  size: 16,
                  color: value == null ? Tone.ink3 : Tone.warn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Tone.ink2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(fontSize: 11, color: Tone.ink3, height: 1.6),
                ),
              ],
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 18,
            color: Tone.ink3,
          ),
        ],
      ),
    );
  }
}
