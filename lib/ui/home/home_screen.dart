import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../services/notifications.dart';
import '../../state/providers.dart';
import '../focus/focus_screen.dart';
import '../habits/habits_screen.dart';
import '../leisure/leisure_screen.dart';
import '../today/today_screen.dart';
import '../vault/vault_screen.dart';
import '../widgets/glass.dart';
import '../wizard/morning_wizard.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  var _bootstrapped = false;
  Timer? _dayWatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _dayWatch = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _onPossibleDayChange(),
      );
    }
  }

  @override
  void dispose() {
    _dayWatch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onPossibleDayChange();
  }

  Future<void> _onPossibleDayChange() async {
    if (!ref.read(dayKeyProvider.notifier).refresh()) return;
    await syncDailyReminders(
      ref.read(repoProvider),
      ref.read(dayKeyProvider),
      ref.read(appLanguageProvider),
    );
    final plan = await ref.read(todayProvider.future);
    if (!mounted) return;
    if (!plan.planned && ref.read(focusProvider) == null) {
      unawaited(openMorningWizard(context, ref));
    }
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await Notifications.instance.requestPermissions();
    Notifications.instance.onHabitsChanged = () {
      if (mounted) ref.invalidate(habitsProvider);
    };
    await Notifications.instance.consumeLaunchAction();
    final lang = ref.read(appLanguageProvider);
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      final habits = await ref.read(habitsProvider.future);
      if (!mounted) return;
      await Notifications.instance.syncHabitReminders(habits, lang: lang);
      if (!mounted) return;
      await syncDailyReminders(
        ref.read(repoProvider),
        ref.read(dayKeyProvider),
        lang,
      );
      if (!mounted) return;
    }
    final restored = await ref.read(focusProvider.notifier).restore();
    if (!mounted) return;
    if (restored) {
      unawaited(Navigator.of(context).push(FocusScreen.route()));
      return;
    }
    _setupQuickActions();
    final plan = await ref.read(todayProvider.future);
    if (!mounted) return;
    if (!plan.planned) {
      if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) unawaited(openMorningWizard(context, ref));
      }
    }
  }

  void _setupQuickActions() {
    try {
      final lang = ref.read(appLanguageProvider);
      const QuickActions()
        ..initialize((type) {
          if (type == 'new_thought' && mounted) {
            setState(() => _currentIndex = 1);
          }
        })
        ..setShortcutItems([
          ShortcutItem(
            type: 'new_thought',
            localizedTitle: lang == AppLanguage.fa
                ? 'ثبت فکر'
                : 'Capture Thought',
            icon: 'ic_stat_dot',
          ),
        ]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accentProvider);
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: const [
              TodayScreen(),
              VaultScreen(),
              HabitsScreen(),
              LeisureScreen(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LiquidGlassNavBar(
              currentIndex: _currentIndex,
              onTap: (i) {
                if (_currentIndex != i) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentIndex = i);
                }
              },
              lang: lang,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final AppLanguage lang;

  const _LiquidGlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      key: const Key('tab_tasks'),
                      icon: Icons.check_circle_outline_rounded,
                      activeIcon: Icons.check_circle_rounded,
                      label: L10n.tasksTab(lang),
                      selected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      key: const Key('tab_vault'),
                      icon: Icons.psychology_outlined,
                      activeIcon: Icons.psychology_rounded,
                      label: L10n.vaultTab(lang),
                      selected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      key: const Key('tab_habits'),
                      icon: Icons.repeat_rounded,
                      activeIcon: Icons.auto_awesome_rounded,
                      label: L10n.habitsTab(lang),
                      selected: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      key: const Key('tab_leisure'),
                      icon: Icons.spa_outlined,
                      activeIcon: Icons.spa_rounded,
                      label: L10n.leisureTab(lang),
                      selected: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Tone.accent.withValues(alpha: .15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: Tone.accent.withValues(alpha: .35))
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                selected ? activeIcon : icon,
                size: 20,
                color: selected ? Tone.accent : Tone.ink3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Tone.accent : Tone.ink3,
                letterSpacing: -.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
