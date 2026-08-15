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
    AppDatabase.fileName = 'test_habits_stats.db';
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

  group('shiftDayKey', () {
    test('shifts forward and backward across month edges', () {
      expect(shiftDayKey('2026-07-07', 1), '2026-07-08');
      expect(shiftDayKey('2026-07-01', -1), '2026-06-30');
      expect(shiftDayKey('2026-12-31', 1), '2027-01-01');
    });
  });

  group('habits', () {
    test('add, log, toggle off, delete', () async {
      final h = await repo.addHabit(
        title: '۱۰ دقیقه ورزش',
        cue: 'قهوهٔ صبح',
        isBad: false,
        badCost: '',
        replacement: '',
        reminderMinutes: 8 * 60,
      );
      final today = todayKey();
      await repo.logHabit(h.id, today, 'done');
      var habits = await repo.habits();
      expect(habits.single.doneOn(today), true);
      expect(habits.single.reminderMinutes, 8 * 60);

      await repo.logHabit(h.id, today, null);
      habits = await repo.habits();
      expect(habits.single.doneOn(today), false);

      await repo.deleteHabit(h.id);
      expect(await repo.habits(), isEmpty);
    });

    test('bad habit stores cost and replacement; slip/resisted log', () async {
      final h = await repo.addHabit(
        title: 'چک کردن اینستاگرام',
        cue: 'دراز کشیدن در تخت',
        isBad: true,
        badCost: 'یک سال دیگر همین‌جا هستم',
        replacement: 'دو صفحه کتاب',
        reminderMinutes: null,
      );
      final today = todayKey();
      await repo.logHabit(h.id, today, 'resisted');
      var loaded = (await repo.habits()).single;
      expect(loaded.statusOn(today), 'resisted');
      expect(loaded.badCost, 'یک سال دیگر همین‌جا هستم');
      expect(loaded.replacement, 'دو صفحه کتاب');

      await repo.logHabit(h.id, today, 'slip');
      loaded = (await repo.habits()).single;
      expect(loaded.statusOn(today), 'slip');
    });
  });

  group('stats', () {
    test('win rate, prediction gap and last nights', () async {
      // Three closed nights: predictions 90/80/70, outcomes win/loss/loss.
      final db = await AppDatabase.instance.db;
      final data = [
        (shiftDayKey(todayKey(), -3), 90, 1),
        (shiftDayKey(todayKey(), -2), 80, 0),
        (shiftDayKey(todayKey(), -1), 70, 0),
      ];
      for (final (key, pred, outcome) in data) {
        await db.insert('days', {
          'day_key': key,
          'planned': 1,
          'prediction': pred,
          'closed_at': 1,
          'outcome': outcome,
          'whys': '[]',
          'note': '',
        });
      }
      final s = await repo.stats();
      expect(s.closedCount, 3);
      expect(s.winRate, 33);
      expect(s.avgPrediction, 80);
      expect(s.gap, 47);
      expect(s.lastNights.length, 3);
      expect(s.lastNights.first.dayKey, data.last.$1); // newest first
    });

    test('recovery rate counts miss→done pairs', () async {
      final db = await AppDatabase.instance.db;
      final today = todayKey();
      // Habit created 5 days ago; missed d-4 (recovered d-3), missed d-2
      // (not recovered d-1).
      await db.insert('habits', {
        'id': 'h1',
        'title': 'ورزش',
        'cue': 'صبح',
        'created': shiftDayKey(today, -5),
        'is_bad': 0,
        'bad_cost': '',
        'replacement': '',
        'sort': 0,
      });
      for (final key in [shiftDayKey(today, -5), shiftDayKey(today, -3)]) {
        await db.insert('habit_logs', {
          'habit_id': 'h1',
          'day_key': key,
          'status': 'done',
        });
      }
      final s = await repo.stats();
      // Missed: d-4, d-2, d-1 → 3 misses; recovered: d-4→d-3 → 1.
      expect(s.recoveryRate, 33);
    });

    test('focus minutes bucket into the right day', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await repo.startFocusSession(
        dayKey: todayKey(),
        taskId: null,
        title: 'کار',
        plannedMin: 25,
      );
      final db = await AppDatabase.instance.db;
      await db.update(
        'focus_sessions',
        {'started_at': now - 25 * 60000, 'ended_at': now, 'completed': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      // A fun session must NOT count as deep work.
      final funId = await repo.startFocusSession(
        dayKey: todayKey(),
        taskId: null,
        title: 'گیم',
        plannedMin: 45,
        kind: 'fun',
      );
      await db.update(
        'focus_sessions',
        {'started_at': now - 45 * 60000, 'ended_at': now, 'completed': 1},
        where: 'id = ?',
        whereArgs: [funId],
      );
      final s = await repo.stats();
      expect(s.focusMinutesLast7[6], 25);
      expect(s.focusMinutesWeek, 25);
    });

    test(
      'golden hour needs at least 6 checks then picks best bucket',
      () async {
        var s = await repo.stats();
        expect(s.goldenHour, isNull);

        final db = await AppDatabase.instance.db;
        // 4 high-energy checks at 10:00, 3 low at 16:00.
        for (var i = 0; i < 4; i++) {
          await db.insert('energy_checks', {
            'id': 'e$i',
            'day_key': todayKey(),
            'hour': 10,
            'level': 3,
          });
        }
        for (var i = 0; i < 3; i++) {
          await db.insert('energy_checks', {
            'id': 'f$i',
            'day_key': todayKey(),
            'hour': 16,
            'level': 1,
          });
        }
        s = await repo.stats();
        expect(s.goldenHour, 9); // bucket 10~/3 = 3 → starts at hour 9
      },
    );

    test('review due after 6 closed nights, then weekly', () async {
      var s = await repo.stats();
      expect(s.reviewDue, false);

      final db = await AppDatabase.instance.db;
      for (var i = 1; i <= 6; i++) {
        await db.insert('days', {
          'day_key': shiftDayKey(todayKey(), -i),
          'planned': 1,
          'prediction': 70,
          'closed_at': 1,
          'outcome': 1,
          'whys': '[]',
          'note': '',
        });
      }
      s = await repo.stats();
      expect(s.reviewDue, true);

      await repo.markReviewDone();
      s = await repo.stats();
      expect(s.reviewDue, false);
    });
  });

  group('fun config', () {
    test('round-trips through settings', () async {
      expect(await repo.funConfig(), isNull);
      await repo.setFunConfig(const FunConfig(title: 'گیم', minutes: 45));
      final fun = await repo.funConfig();
      expect(fun?.title, 'گیم');
      expect(fun?.minutes, 45);
    });
  });

  group('task editing', () {
    Future<void> planThree() async {
      final a = await repo.addBacklog('کار الف');
      final b = await repo.addBacklog('کار ب');
      final c = await repo.addBacklog('کار ج');
      await repo.planDay(
        dayKey: todayKey(),
        selected: [a, b, c],
        boulderId: a.id,
        prediction: 70,
      );
    }

    test('rename updates both today list and backlog', () async {
      await planThree();
      final plan = await repo.dayPlan(todayKey());
      final id = plan.boulderId!;
      await repo.renameTask(todayKey(), id, 'عنوان درست');
      final after = await repo.dayPlan(todayKey());
      expect(after.boulder!.title, 'عنوان درست');
      expect(
        (await repo.backlog()).firstWhere((b) => b.id == id).title,
        'عنوان درست',
      );
    });

    test('deleting the boulder promotes the next task', () async {
      await planThree();
      final plan = await repo.dayPlan(todayKey());
      final boulderId = plan.boulderId!;
      final nextId = plan.others.first.taskId;
      await repo.removeTaskFromDay(todayKey(), boulderId);
      final after = await repo.dayPlan(todayKey());
      expect(after.tasks.length, 2);
      expect(after.boulderId, nextId);
      expect(after.planned, true);
      expect((await repo.backlog()).any((b) => b.id == boulderId), false);
    });

    test('deleting the last task falls back to unplanned', () async {
      final a = await repo.addBacklog('تنها کار');
      await repo.planDay(
        dayKey: todayKey(),
        selected: [a],
        boulderId: a.id,
        prediction: 60,
      );
      await repo.removeTaskFromDay(todayKey(), a.id);
      final after = await repo.dayPlan(todayKey());
      expect(after.tasks, isEmpty);
      expect(after.planned, false);
      expect(after.boulderId, isNull);
    });
  });

  group('interrupt patterns', () {
    test('tag counts aggregate over recent sessions', () async {
      final db = await AppDatabase.instance.db;
      Future<void> ended(String tag) async {
        final id = await repo.startFocusSession(
          dayKey: todayKey(),
          taskId: null,
          title: 'کار',
          plannedMin: 25,
        );
        await repo.endFocusSession(
          sessionId: id,
          completed: false,
          interruptTag: tag,
        );
      }

      await ended('phone');
      await ended('phone');
      await ended('tired');
      // A session with only a note (no tag) must not count in the pattern.
      final noteId = await repo.startFocusSession(
        dayKey: todayKey(),
        taskId: null,
        title: 'کار',
        plannedMin: 25,
      );
      await repo.endFocusSession(
        sessionId: noteId,
        completed: false,
        interruptNote: 'چیزی',
      );

      final s = await repo.stats();
      expect(s.interruptCounts[InterruptTag.phone], 2);
      expect(s.interruptCounts[InterruptTag.tired], 1);
      expect(s.interruptCounts.containsKey(InterruptTag.people), false);
      expect(db.isOpen, true);
    });
  });

  group('optimism reliability', () {
    test('needs at least the minimum closed nights', () async {
      final db = await AppDatabase.instance.db;
      for (var i = 1; i <= StatsData.optimismMinNights - 1; i++) {
        await db.insert('days', {
          'day_key': shiftDayKey(todayKey(), -i),
          'planned': 1,
          'prediction': 90,
          'closed_at': 1,
          'outcome': 0,
          'whys': '[]',
          'note': '',
        });
      }
      expect((await repo.stats()).optimismReliable, false);
      await db.insert('days', {
        'day_key': shiftDayKey(todayKey(), -StatsData.optimismMinNights),
        'planned': 1,
        'prediction': 90,
        'closed_at': 1,
        'outcome': 0,
        'whys': '[]',
        'note': '',
      });
      expect((await repo.stats()).optimismReliable, true);
    });
  });
}
