import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taknoghte/data/database.dart';
import 'package:taknoghte/data/models.dart';
import 'package:taknoghte/data/repo.dart';

void main() {
  late Repo repo;
  const day = '2026-07-07';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.fileName = 'test_repo.db';
  });

  setUp(() async {
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

  group('backlog & UUIDs', () {
    test('add, list (newest first), delete, with valid UUIDs', () async {
      final a = await repo.addBacklog('کار اول');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = await repo.addBacklog('کار دوم');

      // Verify UUID format (8-4-4-4-12 hex characters)
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(uuidRegex.hasMatch(a.id), true);
      expect(uuidRegex.hasMatch(b.id), true);

      final list = await repo.backlog();
      expect(list.map((x) => x.id), [b.id, a.id]);

      await repo.deleteBacklog(a.id);
      expect((await repo.backlog()).map((x) => x.id), [b.id]);
    });
  });

  group('day plan', () {
    test('unplanned day is empty', () async {
      final plan = await repo.dayPlan(day);
      expect(plan.planned, false);
      expect(plan.tasks, isEmpty);
    });

    test('planDay stores tasks, boulder, prediction', () async {
      final a = await repo.addBacklog('تخته‌سنگ');
      final b = await repo.addBacklog('کار دوم');
      await repo.planDay(
        dayKey: day,
        selected: [a, b],
        boulderId: a.id,
        prediction: 70,
      );

      final plan = await repo.dayPlan(day);
      expect(plan.planned, true);
      expect(plan.boulderId, a.id);
      expect(plan.prediction, 70);
      expect(plan.tasks.length, 2);
      expect(plan.boulder?.title, 'تخته‌سنگ');
      expect(plan.others.single.title, 'کار دوم');
    });

    test('replan keeps done flags of surviving tasks', () async {
      final a = await repo.addBacklog('الف');
      final b = await repo.addBacklog('ب');
      await repo.planDay(
        dayKey: day,
        selected: [a],
        boulderId: a.id,
        prediction: 60,
      );
      await repo.setTaskDone(day, a.id, true);

      await repo.planDay(
        dayKey: day,
        selected: [a, b],
        boulderId: b.id,
        prediction: 80,
      );
      final plan = await repo.dayPlan(day);
      expect(plan.tasks.firstWhere((t) => t.taskId == a.id).done, true);
      expect(plan.tasks.firstWhere((t) => t.taskId == b.id).done, false);
      expect(plan.boulderId, b.id);
    });

    test('setTaskDone toggles and boulderDone reflects it', () async {
      final a = await repo.addBacklog('الف');
      await repo.planDay(
        dayKey: day,
        selected: [a],
        boulderId: a.id,
        prediction: 50,
      );
      await repo.setTaskDone(day, a.id, true);
      expect((await repo.dayPlan(day)).boulderDone, true);
      await repo.setTaskDone(day, a.id, false);
      expect((await repo.dayPlan(day)).boulderDone, false);
    });
  });

  group('closeDay', () {
    test('boulder done → outcome true, done tasks leave backlog', () async {
      final a = await repo.addBacklog('تخته‌سنگ');
      final b = await repo.addBacklog('نیمه‌کاره');
      await repo.planDay(
        dayKey: day,
        selected: [a, b],
        boulderId: a.id,
        prediction: 70,
      );
      await repo.setTaskDone(day, a.id, true);

      await repo.closeDay(dayKey: day, whys: [], note: 'روز خوبی بود');

      final plan = await repo.dayPlan(day);
      expect(plan.closed, true);
      expect(plan.outcome, true);
      expect(plan.note, 'روز خوبی بود');
      // completed boulder is scheduled on today, unfinished task stays in backlog
      expect((await repo.backlog()).map((x) => x.id), [b.id]);
    });

    test('boulder not done → outcome false, whys stored', () async {
      final a = await repo.addBacklog('تخته‌سنگ');
      await repo.planDay(
        dayKey: day,
        selected: [a],
        boulderId: a.id,
        prediction: 90,
      );

      await repo.closeDay(
        dayKey: day,
        whys: ['خسته بودم', 'دیر خوابیدم'],
        note: '',
      );

      final plan = await repo.dayPlan(day);
      expect(plan.outcome, false);
      expect(plan.whys, ['خسته بودم', 'دیر خوابیدم']);
      expect((await repo.backlog()).length, 1);
    });
  });

  group('thoughts', () {
    test('add, update, delete', () async {
      await repo.addThought('یک ایده', ThoughtCategory.idea);
      var all = await repo.thoughts();
      expect(all.single.text, 'یک ایده');

      await repo.updateThought(
        all.single.id,
        'ایدهٔ ویرایش‌شده',
        ThoughtCategory.worry,
      );
      all = await repo.thoughts();
      expect(all.single.text, 'ایدهٔ ویرایش‌شده');
      expect(all.single.category, ThoughtCategory.worry);

      await repo.deleteThought(all.single.id);
      expect(await repo.thoughts(), isEmpty);
    });

    test('promote lands on today when planned with room', () async {
      final a = await repo.addBacklog('الف');
      await repo.planDay(
        dayKey: day,
        selected: [a],
        boulderId: a.id,
        prediction: 70,
      );
      await repo.addThought('فکر مهم', ThoughtCategory.sideTask);
      final t = (await repo.thoughts()).single;

      final onToday = await repo.promoteThought(t, day);
      expect(onToday, true);
      final plan = await repo.dayPlan(day);
      expect(plan.tasks.length, 2);
      expect(plan.tasks.any((x) => x.title == 'فکر مهم'), true);
      expect(await repo.thoughts(), isEmpty);
    });

    test('promote goes to backlog only when day is full', () async {
      final items = [
        await repo.addBacklog('۱'),
        await repo.addBacklog('۲'),
        await repo.addBacklog('۳'),
      ];
      await repo.planDay(
        dayKey: day,
        selected: items,
        boulderId: items.first.id,
        prediction: 70,
      );
      await repo.addThought('اضافه', ThoughtCategory.idea);
      final t = (await repo.thoughts()).single;

      final onToday = await repo.promoteThought(t, day);
      expect(onToday, false);
      expect((await repo.dayPlan(day)).tasks.length, 3);
      expect((await repo.backlog()).any((x) => x.title == 'اضافه'), true);
    });
  });

  group('focus sessions', () {
    test('start and end persist completion + interrupt note', () async {
      final id = await repo.startFocusSession(
        dayKey: day,
        taskId: null,
        title: 'تمرکز',
        plannedMin: 25,
      );
      await repo.endFocusSession(
        sessionId: id,
        completed: false,
        interruptNote: 'تلفن زنگ خورد',
      );

      final db = await AppDatabase.instance.db;
      final row = (await db.query(
        'focus_sessions',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      expect(row['id'], id);
      expect(row['completed'], 0);
      expect(row['interrupt_note'], 'تلفن زنگ خورد');
      expect(row['ended_at'], isNotNull);
      expect(row['planned_min'], 25);
    });
  });
}
