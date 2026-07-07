import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taknoghte/core/fa.dart';
import 'package:taknoghte/data/database.dart';
import 'package:taknoghte/data/models.dart';
import 'package:taknoghte/data/repo.dart';

void main() {
  late Repo repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDatabase.fileName = 'test_sprint1.db';
  });

  setUp(() async {
    repo = Repo();
    final db = await AppDatabase.instance.db;
    for (final t in [
      'backlog',
      'days',
      'day_tasks',
      'thoughts',
      'focus_sessions',
      'habits',
      'habit_logs',
      'energy_checks',
      'settings',
    ]) {
      await db.delete(t);
    }
  });

  group('promoteThought on a closed day', () {
    test('goes to backlog only, never onto the closed day', () async {
      final today = todayKey();
      final a = await repo.addBacklog('تخته‌سنگ');
      await repo.planDay(
        dayKey: today,
        selected: [a],
        boulderId: a.id,
        prediction: 70,
      );
      await repo.setTaskDone(today, a.id, true);
      await repo.closeDay(dayKey: today, whys: [], note: '');

      await repo.addThought('فکر بعد از بستن روز', ThoughtCategory.idea);
      final thought = (await repo.thoughts()).single;
      final onToday = await repo.promoteThought(thought, today);

      expect(onToday, false);
      final plan = await repo.dayPlan(today);
      expect(plan.tasks.length, 1, reason: 'closed day must stay untouched');
      final backlog = await repo.backlog();
      expect(backlog.single.title, 'فکر بعد از بستن روز');
    });
  });

  group('thought undo', () {
    test('restoreThought puts it back with the same id and time', () async {
      await repo.addThought('مهم', ThoughtCategory.worry);
      final original = (await repo.thoughts()).single;
      await repo.deleteThought(original.id);
      expect(await repo.thoughts(), isEmpty);

      await repo.restoreThought(original);
      final restored = (await repo.thoughts()).single;
      expect(restored.id, original.id);
      expect(restored.text, 'مهم');
      expect(restored.category, ThoughtCategory.worry);
      expect(restored.createdAt, original.createdAt);
    });
  });

  group('focus session closing', () {
    test('endedAtMs closes an expired session at its real end time', () async {
      final id = await repo.startFocusSession(
        dayKey: todayKey(),
        taskId: null,
        title: 'کار',
        plannedMin: 25,
      );
      final realEnd = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      await repo.endFocusSession(
        sessionId: id,
        completed: true,
        endedAtMs: realEnd,
      );
      final db = await AppDatabase.instance.db;
      final row = (await db.query(
        'focus_sessions',
        where: 'id = ?',
        whereArgs: [id],
      )).single;
      expect(row['ended_at'], realEnd);
      expect(row['completed'], 1);
    });

    test(
      'a later end() refines outcome without erasing interrupt note',
      () async {
        final id = await repo.startFocusSession(
          dayKey: todayKey(),
          taskId: null,
          title: 'کار',
          plannedMin: 25,
        );
        await repo.endFocusSession(
          sessionId: id,
          completed: false,
          interruptNote: 'موبایل',
        );
        // «هنوز نه» after restore: no note passed — note must survive.
        await repo.endFocusSession(sessionId: id, completed: false);
        final db = await AppDatabase.instance.db;
        final row = (await db.query(
          'focus_sessions',
          where: 'id = ?',
          whereArgs: [id],
        )).single;
        expect(row['interrupt_note'], 'موبایل');
      },
    );
  });

  group('reminder settings', () {
    test('defaults, custom value, and off state', () async {
      expect(
        await repo.reminderMinutes('rem_morning', Repo.defaultMorningMin),
        Repo.defaultMorningMin,
      );
      await repo.setReminderMinutes('rem_morning', 7 * 60);
      expect(
        await repo.reminderMinutes('rem_morning', Repo.defaultMorningMin),
        7 * 60,
      );
      await repo.setReminderMinutes('rem_morning', null);
      expect(
        await repo.reminderMinutes('rem_morning', Repo.defaultMorningMin),
        isNull,
      );
    });
  });

  group('backup / restore', () {
    test('export → wipe → import round-trips every table', () async {
      final today = todayKey();
      final a = await repo.addBacklog('کار مهم');
      await repo.planDay(
        dayKey: today,
        selected: [a],
        boulderId: a.id,
        prediction: 80,
      );
      await repo.addThought('ایده‌ی ناب', ThoughtCategory.idea);
      final h = await repo.addHabit(
        title: 'ورزش',
        cue: 'قهوه',
        isBad: false,
        badCost: '',
        replacement: '',
        reminderMinutes: 8 * 60,
      );
      await repo.logHabit(h.id, today, 'done');
      await repo.addEnergyCheck(3);
      await repo.setFunConfig(const FunConfig(title: 'گیم', minutes: 30));

      final backup = await repo.exportJson();

      // Simulate a fresh install.
      final db = await AppDatabase.instance.db;
      for (final t in [
        'backlog',
        'days',
        'day_tasks',
        'thoughts',
        'habits',
        'habit_logs',
        'energy_checks',
        'settings',
      ]) {
        await db.delete(t);
      }
      expect(await repo.backlog(), isEmpty);

      await repo.importJson(backup);

      expect((await repo.backlog()).single.title, 'کار مهم');
      final plan = await repo.dayPlan(today);
      expect(plan.planned, true);
      expect(plan.prediction, 80);
      expect((await repo.thoughts()).single.text, 'ایده‌ی ناب');
      final habit = (await repo.habits()).single;
      expect(habit.title, 'ورزش');
      expect(habit.doneOn(today), true);
      expect((await repo.funConfig())?.title, 'گیم');
    });

    test('rejects foreign or corrupt files', () async {
      expect(
        () => repo.importJson('{"hello": "world"}'),
        throwsFormatException,
      );
      expect(() => repo.importJson('not json at all'), throwsFormatException);
    });
  });
}
