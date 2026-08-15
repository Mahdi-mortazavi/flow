import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taknoghte/core/fa.dart';
import 'package:taknoghte/core/l10n.dart';
import 'package:taknoghte/core/theme.dart';
import 'package:taknoghte/data/database.dart';
import 'package:taknoghte/data/models.dart';
import 'package:taknoghte/data/repo.dart';
import 'package:taknoghte/services/notifications.dart';
import 'package:taknoghte/state/providers.dart';
import 'package:taknoghte/ui/today/today_screen.dart';
import 'package:taknoghte/ui/widgets/glass.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Repo repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.fileName = 'test_task_reminders.db';
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

  group('Task Reminder Notifications & Scheduling', () {
    test('taskNotifId produces consistent deterministic integer ids', () {
      final id1 = Notifications.taskNotifId('task-uuid-1234');
      final id2 = Notifications.taskNotifId('task-uuid-1234');
      final id3 = Notifications.taskNotifId('task-uuid-5678');

      expect(id1, equals(id2));
      expect(id1, greaterThanOrEqualTo(20000));
      expect(id1, isNot(equals(id3)));
    });

    test(
      'scheduleTaskReminder and cancelTaskReminder handle calls gracefully',
      () async {
        await Notifications.instance.init();
        await Notifications.instance.scheduleTaskReminder(
          taskId: 'test-task-1',
          taskTitle: 'Important task',
          minutesOfDay: 14 * 60 + 30,
          dayKey: todayKey(),
          lang: AppLanguage.en,
        );

        await Notifications.instance.cancelTaskReminder('test-task-1');
      },
    );

    test(
      'Repo updateTaskReminder persists and getTask retrieves reminder_time',
      () async {
        final item = await repo.addBacklog('Deep reading');
        expect(item.id, isNotEmpty);

        var task = await repo.getTask(item.id);
        expect(task, isNotNull);
        expect(task!.reminderTime, isNull);

        await repo.updateTaskReminder(item.id, 630); // 10:30
        task = await repo.getTask(item.id);
        expect(task!.reminderTime, equals(630));

        await repo.updateTaskReminder(item.id, null);
        task = await repo.getTask(item.id);
        expect(task!.reminderTime, isNull);
      },
    );

    test(
      'TodayController updates reminder and cancels upon completion/removal',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final r = container.read(repoProvider);
        final item1 = await r.addBacklog('Write report');
        final item2 = await r.addBacklog('Design logo');

        await container
            .read(todayProvider.notifier)
            .plan(
              selected: [item1, item2],
              boulderId: item1.id,
              prediction: 85,
            );

        var plan = await container.read(todayProvider.future);
        expect(plan.tasks.length, equals(2));

        // Update reminder time for item1
        await container
            .read(todayProvider.notifier)
            .updateTaskReminder(item1.id, 570); // 09:30

        plan = await container.read(todayProvider.future);
        final task1 = plan.tasks.firstWhere((t) => t.taskId == item1.id);
        expect(task1.reminderTime, equals(570));

        // Marking task done cancels reminder
        await container
            .read(todayProvider.notifier)
            .setTaskDone(item1.id, true);
        plan = await container.read(todayProvider.future);
        expect(plan.tasks.firstWhere((t) => t.taskId == item1.id).done, isTrue);

        // Removing task cancels reminder
        await container.read(todayProvider.notifier).removeTask(item2.id);
        plan = await container.read(todayProvider.future);
        expect(plan.tasks.any((t) => t.taskId == item2.id), isFalse);
      },
    );

    test(
      'onTaskLaunch parses task callback and fetches task details for focus',
      () async {
        final item = await repo.addBacklog('Notification Deep Work');
        String? launchedTaskId;
        String? launchedTitle;

        Notifications.instance.onTaskLaunch = (taskId, actionId) async {
          final task = await repo.getTask(taskId);
          if (task != null) {
            launchedTaskId = task.id;
            launchedTitle = task.title;
          }
        };

        Notifications.instance.onTaskLaunch?.call(item.id, 'task_focus');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(launchedTaskId, equals(item.id));
        expect(launchedTitle, equals('Notification Deep Work'));
      },
    );

    test('L10n formats reminder times in fa and en correctly', () {
      expect(L10n.fmtTime(630, AppLanguage.fa), equals('۱۰:۳۰'));
      expect(L10n.fmtTime(630, AppLanguage.en), equals('10:30'));
      expect(
        L10n.taskReminderChannelName(AppLanguage.fa),
        equals('یادآور کارها'),
      );
      expect(
        L10n.taskReminderChannelName(AppLanguage.en),
        equals('Task Reminders'),
      );
    });

    testWidgets(
      'TodayScreen displays reminder badge on task card with reminder',
      (tester) async {
        const mockPlan = DayPlan(
          dayKey: '2026-08-15',
          planned: true,
          tasks: [
            DayTask(
              taskId: 'boulder-task-id',
              title: 'Boulder Task',
              done: false,
              sort: 0,
              isBoulder: true,
              reminderTime: 630, // 10:30 -> ۱۰:۳۰ in fa
            ),
            DayTask(
              taskId: 'secondary-task-id',
              title: 'Secondary Task',
              done: false,
              sort: 1,
              reminderTime: 870, // 14:30 -> ۱۴:۳۰ in fa
            ),
          ],
          boulderId: 'boulder-task-id',
          prediction: 80,
          closed: false,
          outcome: null,
          whys: [],
          note: '',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todayProvider.overrideWith(() => _TestTodayController(mockPlan)),
              appLanguageProvider.overrideWith(
                () => _TestAppLanguageController(AppLanguage.fa),
              ),
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

        expect(find.text('Boulder Task'), findsOneWidget);
        expect(find.text('۱۰:۳۰'), findsOneWidget);
        expect(find.text('Secondary Task'), findsOneWidget);
        expect(find.text('۱۴:۳۰'), findsOneWidget);
      },
    );

    testWidgets(
      'showWheelTimePicker displays Set button in English',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appLanguageProvider.overrideWith(
                () => _TestAppLanguageController(AppLanguage.en),
              ),
            ],
            child: MaterialApp(
              theme: buildTheme(Tone.ember),
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        showWheelTimePicker(context, initialMinutes: 600),
                    child: const Text('open_en'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_en'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Set'), findsOneWidget);
        expect(find.text('Select Time'), findsOneWidget);
      },
    );

    testWidgets(
      'showWheelTimePicker displays تنظیم button in Persian',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appLanguageProvider.overrideWith(
                () => _TestAppLanguageController(AppLanguage.fa),
              ),
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
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        showWheelTimePicker(context, initialMinutes: 600),
                    child: const Text('open_fa'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open_fa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('تنظیم'), findsOneWidget);
        expect(find.text('انتخاب ساعت'), findsOneWidget);
      },
    );
  });
}
