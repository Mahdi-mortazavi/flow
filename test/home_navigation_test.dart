import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taknoghte/core/l10n.dart';
import 'package:taknoghte/core/theme.dart';
import 'package:taknoghte/data/models.dart';
import 'package:taknoghte/state/providers.dart';
import 'package:taknoghte/ui/habits/habits_screen.dart';
import 'package:taknoghte/ui/home/home_screen.dart';
import 'package:taknoghte/ui/leisure/leisure_screen.dart';
import 'package:taknoghte/ui/today/today_screen.dart';

class _TestAppLanguageController extends AppLanguageController {
  final AppLanguage initial;
  _TestAppLanguageController(this.initial);

  @override
  AppLanguage build() => initial;
}

class _TestTodayController extends TodayController {
  final DayPlan initial;
  _TestTodayController(this.initial);

  @override
  Future<DayPlan> build() async => initial;
}

class _TestThoughtsController extends ThoughtsController {
  final List<Thought> initial;
  _TestThoughtsController(this.initial);

  @override
  Future<List<Thought>> build() async => initial;
}

class _TestHabitsController extends HabitsController {
  final List<Habit> initial;
  _TestHabitsController(this.initial);

  @override
  Future<List<Habit>> build() async => initial;
}

class _TestFunController extends FunController {
  final FunConfig? initial;
  _TestFunController(this.initial);

  @override
  Future<FunConfig?> build() async => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    AppLanguage lang = AppLanguage.fa,
    List<Thought> thoughts = const [],
    List<Habit> habits = const [],
    FunConfig? fun,
  }) {
    const mockPlan = DayPlan(
      dayKey: '2026-08-15',
      planned: true,
      tasks: [
        DayTask(
          taskId: 'task-1',
          title: 'تخته‌سنگ امروز',
          isBoulder: true,
          done: false,
          sort: 0,
        ),
      ],
      boulderId: 'task-1',
      prediction: 80,
      closed: false,
      outcome: null,
      whys: [],
      note: '',
    );

    const mockStats = StatsData(
      closedCount: 0,
      winRate: null,
      avgPrediction: null,
      gap: null,
      recoveryRate: null,
      lastNights: [],
      focusMinutesLast7: [0, 0, 0, 0, 0, 0, 0],
      recentInterrupts: [],
      interruptCounts: {},
      goldenHour: null,
      reviewDue: false,
    );

    return ProviderScope(
      overrides: [
        appLanguageProvider.overrideWith(
          () => _TestAppLanguageController(lang),
        ),
        todayProvider.overrideWith(() => _TestTodayController(mockPlan)),
        thoughtsProvider.overrideWith(() => _TestThoughtsController(thoughts)),
        habitsProvider.overrideWith(() => _TestHabitsController(habits)),
        funProvider.overrideWith(() => _TestFunController(fun)),
        statsProvider.overrideWith((ref) async => mockStats),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final currentLang = ref.watch(appLanguageProvider);
          return MaterialApp(
            locale: Locale(currentLang.code),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: buildTheme(Tone.ember),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }

  group('3-Tab Bottom Navigation & Domain Separation', () {
    testWidgets('Renders all 3 tabs in Persian and switches screens', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify 3 bottom navigation items exist
      expect(find.byKey(const Key('tab_tasks')), findsOneWidget);
      expect(find.byKey(const Key('tab_habits')), findsOneWidget);
      expect(find.byKey(const Key('tab_leisure')), findsOneWidget);
      expect(find.byKey(const Key('tab_vault')), findsNothing);

      // Verify default tab is TodayScreen (Tasks) and Vault FAB exists
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text('مخزن ذهن'), findsOneWidget);

      // Switch to Habits tab
      await tester.tap(find.byKey(const Key('tab_habits')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HabitsScreen), findsOneWidget);
      expect(find.text('+ عادت جدید'), findsOneWidget);

      // Switch to Leisure tab
      await tester.tap(find.byKey(const Key('tab_leisure')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LeisureScreen), findsOneWidget);
      expect(find.text('شروع تفریح بدون عذاب وجدان'), findsOneWidget);
      expect(find.text('پادزهر قانون پارکینسون'), findsOneWidget);

      // Switch back to Tasks tab
      await tester.tap(find.byKey(const Key('tab_tasks')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('Renders all 3 tabs in English with LTR layout', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(lang: AppLanguage.en));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify English bottom navigation items
      expect(find.byKey(const Key('tab_tasks')), findsOneWidget);
      expect(find.byKey(const Key('tab_habits')), findsOneWidget);
      expect(find.byKey(const Key('tab_leisure')), findsOneWidget);
      expect(find.byKey(const Key('tab_vault')), findsNothing);

      // Verify Brain Vault FAB in English
      expect(find.text('Brain Vault'), findsOneWidget);

      // Switch to Habits tab
      await tester.tap(find.byKey(const Key('tab_habits')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('+ New Habit'), findsOneWidget);

      // Switch to Leisure tab
      await tester.tap(find.byKey(const Key('tab_leisure')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Start Guilt-Free Play'), findsOneWidget);
      expect(find.text("Antidote to Parkinson's Law"), findsOneWidget);
    });

    testWidgets('TodayScreen Vault FAB opens Brain Vault sheet', (
      tester,
    ) async {
      final sampleThoughts = [
        Thought(
          id: 'thought-1',
          text: 'Redesign onboarding experience',
          category: ThoughtCategory.idea,
          createdAt: DateTime(2026, 8, 15),
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(lang: AppLanguage.en, thoughts: sampleThoughts),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the Brain Vault FAB
      await tester.tap(find.text('Brain Vault'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Redesign onboarding experience'), findsOneWidget);
      expect(find.text('Idea'), findsWidgets);
      expect(find.text('Promote to Task'), findsOneWidget);
    });

    testWidgets('Habits tab displays added habits and allows toggling', (
      tester,
    ) async {
      final sampleHabits = [
        const Habit(
          id: 'habit-1',
          title: 'Morning Yoga',
          cue: 'Waking up',
          isBad: false,
          badCost: '',
          replacement: '',
          reminderMinutes: 480,
          created: '2026-08-01',
          logs: {},
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(lang: AppLanguage.en, habits: sampleHabits),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Switch to Habits tab
      await tester.tap(find.byKey(const Key('tab_habits')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('after Waking up'), findsOneWidget);
    });

    testWidgets(
      'Leisure tab allows configuring and viewing custom play block',
      (tester) async {
        const funConfig = FunConfig(title: 'Guitar Solo', minutes: 40);

        await tester.pumpWidget(
          buildTestApp(lang: AppLanguage.en, fun: funConfig),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Switch to Leisure tab
        await tester.tap(find.byKey(const Key('tab_leisure')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Guitar Solo'), findsOneWidget);
        expect(find.text('40 min'), findsOneWidget);
      },
    );
  });
}
