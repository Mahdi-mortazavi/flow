import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taknoghte/core/l10n.dart';
import 'package:taknoghte/core/theme.dart';
import 'package:taknoghte/data/database.dart';
import 'package:taknoghte/data/models.dart';
import 'package:taknoghte/state/focus_controller.dart';
import 'package:taknoghte/state/providers.dart';
import 'package:taknoghte/ui/focus/focus_screen.dart';
import 'package:taknoghte/ui/habits/habits_screen.dart';
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

class _TestFocusController extends FocusController {
  final FocusView? initial;
  _TestFocusController(this.initial);

  @override
  FocusView? build() => initial;
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
    AppDatabase.fileName = 'test_portrait_responsive.db';
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  const mockPlan = DayPlan(
    dayKey: '2026-08-16',
    planned: true,
    tasks: [
      DayTask(
        taskId: 'boulder-id',
        title:
            'Very Long Boulder Task Title That Might Wrap Across Multiple Lines In Portrait Mode',
        done: false,
        sort: 0,
        isBoulder: true,
        reminderTime: 630,
      ),
      DayTask(
        taskId: 'task-2',
        title:
            'Secondary Task With Comprehensive Description For Overflow Testing',
        done: false,
        sort: 1,
        reminderTime: 870,
      ),
      DayTask(
        taskId: 'task-3',
        title: 'Another Routine Task',
        done: true,
        sort: 2,
      ),
      DayTask(
        taskId: 'task-4',
        title: 'Pebble 1: Quick side item',
        done: false,
        sort: 3,
      ),
      DayTask(
        taskId: 'task-5',
        title: 'Pebble 2: Another small item',
        done: false,
        sort: 4,
      ),
    ],
    boulderId: 'boulder-id',
    prediction: 80,
    closed: false,
    outcome: null,
    whys: [],
    note: '',
  );

  const mockStats = StatsData(
    closedCount: 5,
    winRate: 80,
    avgPrediction: 75,
    gap: 5,
    recoveryRate: 100,
    lastNights: [],
    focusMinutesLast7: [25, 50, 75, 25, 0, 90, 45],
    recentInterrupts: [],
    interruptCounts: {
      InterruptTag.phone: 3,
      InterruptTag.people: 2,
      InterruptTag.tired: 1,
    },
    goldenHour: 10,
    reviewDue: true,
  );

  group('English vs Persian Focus Timer Clock', () {
    test(
      'L10n.fmtClock formats English digits in English and Persian digits in Persian',
      () {
        const remainingSec = 24 * 60 + 35; // 24:35

        final enClock = L10n.fmtClock(remainingSec, AppLanguage.en);
        final faClock = L10n.fmtClock(remainingSec, AppLanguage.fa);

        expect(enClock, equals('24:35'));
        expect(faClock, equals('۲۴:۳۵'));
      },
    );
  });

  group('Portrait Viewport Responsiveness & Zero Overflow Tests', () {
    testWidgets(
      'FocusScreen renders cleanly without overflows on small viewport with 1.3x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2, 600 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const activeFocus = ActiveFocus(
          sessionId: 'session-123',
          taskId: 'boulder-id',
          title:
              'Refactor complex responsive Flutter layout across multiple devices',
          totalSec: 25 * 60,
          endAtMs: 1700000000000,
          paused: false,
          pausedLeftSec: 25 * 60,
        );

        final container = ProviderContainer(
          overrides: [
            appLanguageProvider.overrideWith(
              () => _TestAppLanguageController(AppLanguage.en),
            ),
            focusProvider.overrideWith(
              () => _TestFocusController(
                const FocusView(activeFocus, 24 * 60 + 50, false),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 600),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                theme: buildTheme(Tone.ember),
                home: const FocusScreen(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('24:50'), findsOneWidget);
        expect(find.text('Focus Session'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'TodayScreen renders without overflows on narrow 360dp viewport with 1.3x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(360 * 2, 640 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todayProvider.overrideWith(() => _TestTodayController(mockPlan)),
              appLanguageProvider.overrideWith(
                () => _TestAppLanguageController(AppLanguage.fa),
              ),
              statsProvider.overrideWith((ref) async => mockStats),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                locale: const Locale('fa'),
                supportedLocales: const [Locale('fa'), Locale('en')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: buildTheme(Tone.ember),
                home: const Scaffold(body: TodayScreen()),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(TodayScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HabitsScreen renders without overflows on narrow viewport with 1.3x text scale',
      (tester) async {
        final habits = [
          const Habit(
            id: 'h1',
            title: 'Daily Morning Exercise And Stretching Routine',
            cue: 'Waking up and drinking a glass of water',
            isBad: false,
            badCost: '',
            replacement: '',
            reminderMinutes: null,
            created: '2026-08-01',
            logs: {'2026-08-16': 'done'},
          ),
          const Habit(
            id: 'h2',
            title: 'Excessive Social Media Scrolling',
            cue: 'Feeling bored or stressed after work',
            isBad: true,
            badCost:
                'Wasted hours and reduced mental clarity over the long term',
            replacement: 'Deep breathing and mindful reading',
            reminderMinutes: null,
            created: '2026-08-01',
            logs: {},
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsProvider.overrideWith(() => _TestHabitsController(habits)),
              appLanguageProvider.overrideWith(
                () => _TestAppLanguageController(AppLanguage.en),
              ),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                theme: buildTheme(Tone.ember),
                home: const Scaffold(body: HabitsScreen()),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(HabitsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LeisureScreen and VaultScreen render cleanly on narrow viewport',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              funProvider.overrideWith(
                () => _TestFunController(
                  const FunConfig(
                    title: 'Mindful Gaming & Exploration',
                    minutes: 45,
                  ),
                ),
              ),
              todayProvider.overrideWith(() => _TestTodayController(mockPlan)),
              appLanguageProvider.overrideWith(
                () => _TestAppLanguageController(AppLanguage.fa),
              ),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaterialApp(
                locale: const Locale('fa'),
                supportedLocales: const [Locale('fa'), Locale('en')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: buildTheme(Tone.ember),
                home: const Scaffold(body: LeisureScreen()),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(LeisureScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
