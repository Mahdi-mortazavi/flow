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
import 'package:taknoghte/data/repo.dart';
import 'package:taknoghte/state/focus_controller.dart';
import 'package:taknoghte/state/providers.dart';
import 'package:taknoghte/ui/focus/focus_screen.dart';
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

class _MockFocusController extends FocusController {
  final FocusView? initial;
  _MockFocusController(this.initial);

  @override
  FocusView? build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Repo repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.fileName = 'test_focus_workflow.db';
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = Repo();
    final db = await AppDatabase.instance.db;
    for (final t in [
      'tasks',
      'days',
      'thoughts',
      'focus_sessions',
      'habits',
      'habit_logs',
      'leisure',
      'energy_checks',
      'settings',
      'backlog',
      'day_tasks',
    ]) {
      await db.delete(t);
    }
  });

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

  group('Direct Task-to-Focus Workflow & Auto-Completion', () {
    test(
      'Starting focus session correctly binds taskId and logs to focus_sessions',
      () async {
        final container = ProviderContainer(
          overrides: [repoProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        const taskId = 'task-uuid-123';
        const taskTitle = 'Refactor database models';

        await container
            .read(focusProvider.notifier)
            .start(taskId: taskId, title: taskTitle);

        final view = container.read(focusProvider);
        expect(view, isNotNull);
        expect(view!.focus.taskId, taskId);
        expect(view.focus.title, taskTitle);
        expect(view.focus.totalSec, 25 * 60);

        final db = await AppDatabase.instance.db;
        final rows = await db.query(
          'focus_sessions',
          where: 'task_id = ?',
          whereArgs: [taskId],
        );
        expect(rows.length, 1);
        expect(rows.first['task_id'], taskId);
        expect(rows.first['title'], taskTitle);
        expect(rows.first['planned_min'], 25);
      },
    );

    test(
      'Ending focus with completed: true logs duration in focus_sessions',
      () async {
        final container = ProviderContainer(
          overrides: [repoProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        const taskId = 'task-uuid-456';
        await container
            .read(focusProvider.notifier)
            .start(taskId: taskId, title: 'Implement focus ring', minutes: 10);

        final focus = container.read(focusProvider)!.focus;

        await container
            .read(focusProvider.notifier)
            .end(completed: true, durationSeconds: 10 * 60);

        final db = await AppDatabase.instance.db;
        final rows = await db.query(
          'focus_sessions',
          where: 'id = ?',
          whereArgs: [focus.sessionId],
        );
        expect(rows.length, 1);
        expect(rows.first['completed'], 1);
        expect(rows.first['duration_seconds'], 10 * 60);
        expect(rows.first['completed_at'], isNotNull);
        expect(container.read(focusProvider), isNull);
      },
    );

    test(
      'Pausing focus and ending later logs actual worked seconds, not wall-clock gap',
      () async {
        final container = ProviderContainer(
          overrides: [repoProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await container
            .read(focusProvider.notifier)
            .start(taskId: 'task-pause-1', title: 'Deep coding');

        // Pause after 10 minutes remaining (15 minutes worked)
        final notifier = container.read(focusProvider.notifier);
        await notifier.pause();

        // Simulate that 8 hours passed while paused by shifting started_at backwards in DB
        final focus = container.read(focusProvider)!.focus;
        final db = await AppDatabase.instance.db;
        final eightHoursAgo =
            DateTime.now().millisecondsSinceEpoch - (8 * 3600 * 1000);
        await db.update(
          'focus_sessions',
          {'started_at': eightHoursAgo},
          where: 'id = ?',
          whereArgs: [focus.sessionId],
        );

        // End session with completed: true (e.g. session countdown completed or user completed work)
        await notifier.end(completed: true, durationSeconds: 25 * 60);

        final rows = await db.query(
          'focus_sessions',
          where: 'id = ?',
          whereArgs: [focus.sessionId],
        );
        expect(rows.length, 1);
        expect(
          rows.first['duration_seconds'],
          25 * 60,
        ); // 25 minutes, NOT 8+ hours

        // Check mirror / stats: deep-work minutes for today should be 25 min, not 480 min
        final stats = await repo.stats();
        expect(stats.focusMinutesLast7[6], 25);
      },
    );

    testWidgets(
      'TodayScreen displays direct Focus action on task card and boulder',
      (tester) async {
        const mockPlan = DayPlan(
          dayKey: '2026-08-15',
          planned: true,
          tasks: [
            DayTask(
              taskId: 'task-boulder-1',
              title: 'Complete deep work boulder',
              isBoulder: true,
              done: false,
              sort: 0,
            ),
            DayTask(
              taskId: 'task-secondary-2',
              title: 'Review PR changes',
              done: false,
              sort: 1,
            ),
          ],
          boulderId: 'task-boulder-1',
          prediction: 85,
          closed: false,
          outcome: null,
          whys: [],
          note: '',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repoProvider.overrideWithValue(repo),
              todayProvider.overrideWith(() => _TestTodayController(mockPlan)),
              statsProvider.overrideWith((ref) async => mockStats),
            ],
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
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('شروع تمرکز'), findsOneWidget);
        expect(find.text('تمرکز'), findsOneWidget);
      },
    );

    testWidgets(
      'FocusScreen displays active task title prominently within the timer ring',
      (tester) async {
        const activeFocus = ActiveFocus(
          sessionId: 'session-1',
          taskId: 'task-1',
          title: 'Design Liquid Glass Ring',
          totalSec: 1500,
          endAtMs: 2000000000000,
          paused: false,
          pausedLeftSec: 1500,
        );

        const view = FocusView(activeFocus, 1500, false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appLanguageProvider.overrideWith(
                () => _TestAppLanguageController(AppLanguage.en),
              ),
              repoProvider.overrideWithValue(repo),
              focusProvider.overrideWith(() => _MockFocusController(view)),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: const [Locale('fa'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: buildTheme(Tone.ember),
              home: const FocusScreen(),
            ),
          ),
        );

        await tester.pump();

        // Verify task title is rendered prominently inside ring
        expect(find.text('Design Liquid Glass Ring'), findsOneWidget);
        expect(find.text('Focus Session'), findsOneWidget);
        expect(find.text('End Early'), findsOneWidget);
      },
    );
  });
}
