import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/fa.dart';
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
    await syncDailyReminders(repo, ref.read(dayKeyProvider));
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

  Future<void> _import() async {
    final picked = await FilePicker.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    final path = picked?.files.single.path;
    if (picked == null || (bytes == null && path == null)) return;
    if (!mounted) return;
    final (yes, _) = await showConfirmSheet(
      context,
      title: 'بازیابی از پشتیبان؟',
      sub:
          'همهٔ داده‌های فعلی با محتوای فایل جایگزین می‌شود. این عمل قابل برگشت نیست.',
      yesLabel: 'جایگزین کن',
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
      );
      if (mounted) showToast(context, 'بازیابی انجام شد');
    } on FormatException {
      if (mounted) showToast(context, 'این فایل، پشتیبانِ تک‌نقطه نیست');
    }
  }

  Future<void> _openBatterySettings() async {
    if (!Platform.isAndroid) return;
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  String _fmt(int? m) => m == null
      ? 'خاموش'
      : faNum(
          '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}',
        );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 220);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(
          'یادآورها و پشتیبان',
          sub: 'چرخهٔ روزانه بدون یادآور می‌میرد؛ داده بدون پشتیبان.',
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            children: [
              _timeRow(
                icon: Icons.wb_twilight_rounded,
                title: 'یادآور صبح',
                sub: 'اگر روز هنوز چیده نشده باشد',
                value: _morning,
                onPick: () async {
                  final v = await showWheelTimePicker(
                    context,
                    initialMinutes: _morning ?? Repo.defaultMorningMin,
                    title: 'ساعتِ یادآور صبح',
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
                title: 'یادآور شب',
                sub: 'اگر روز هنوز بسته نشده باشد',
                value: _evening,
                onPick: () async {
                  final v = await showWheelTimePicker(
                    context,
                    initialMinutes: _evening ?? Repo.defaultEveningMin,
                    title: 'ساعتِ یادآور شب',
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
                title: 'پشتیبان‌گیری (خروجی JSON)',
                sub: 'همهٔ داده‌ها در یک فایل — هر جا خواستی نگهش دار',
                onTap: _export,
              ),
              const SizedBox(height: 9),
              _actionRow(
                icon: Icons.settings_backup_restore_rounded,
                title: 'بازیابی از فایل پشتیبان',
                sub: 'جایگزینی کامل داده‌های فعلی',
                onTap: _import,
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 22),
                _actionRow(
                  icon: Icons.battery_alert_rounded,
                  title: 'یادآورها نمی‌آیند؟',
                  sub:
                      'در برخی گوشی‌ها (شیائومی، هواوی…) باید اپ را از بهینه‌سازی باتری مستثنا کنی',
                  onTap: _openBatterySettings,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeRow({
    required IconData icon,
    required String title,
    required String sub,
    required int? value,
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
            _fmt(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: value == null ? Tone.ink3 : Tone.ember,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Semantics(
            button: true,
            label: value == null ? 'روشن کردن' : 'خاموش کردن',
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
          Icon(Icons.chevron_left_rounded, size: 18, color: Tone.ink3),
        ],
      ),
    );
  }
}
