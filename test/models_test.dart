import 'package:flutter_test/flutter_test.dart';
import 'package:taknoghte/data/models.dart';

ActiveFocus _focus({
  int totalSec = 1500,
  int? endAtMs,
  bool paused = false,
  int pausedLeftSec = 1500,
}) => ActiveFocus(
  sessionId: 's1',
  taskId: 't1',
  title: 'کار مهم',
  totalSec: totalSec,
  endAtMs:
      endAtMs ??
      DateTime.now().add(Duration(seconds: totalSec)).millisecondsSinceEpoch,
  paused: paused,
  pausedLeftSec: pausedLeftSec,
);

void main() {
  group('ActiveFocus', () {
    test('JSON round-trip preserves every field', () {
      final f = _focus(paused: true, pausedLeftSec: 730);
      final back = ActiveFocus.fromJson(f.toJson())!;
      expect(back.sessionId, f.sessionId);
      expect(back.taskId, f.taskId);
      expect(back.title, f.title);
      expect(back.totalSec, f.totalSec);
      expect(back.endAtMs, f.endAtMs);
      expect(back.paused, true);
      expect(back.pausedLeftSec, 730);
    });

    test('fromJson tolerates garbage and null', () {
      expect(ActiveFocus.fromJson(null), isNull);
      expect(ActiveFocus.fromJson(''), isNull);
      expect(ActiveFocus.fromJson('not json'), isNull);
      expect(ActiveFocus.fromJson('{"half": true}'), isNull);
    });

    test('remainingSec is wall-clock based when running', () {
      final f = _focus(totalSec: 60);
      final r = f.remainingSec();
      expect(r, inInclusiveRange(58, 60));
    });

    test('remainingSec returns frozen value when paused', () {
      final f = _focus(paused: true, pausedLeftSec: 42);
      expect(f.remainingSec(), 42);
    });

    test('remainingSec clamps to zero after endAt has passed', () {
      final f = _focus(
        endAtMs: DateTime.now()
            .subtract(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      );
      expect(f.remainingSec(), 0);
    });
  });

  group('DayPlan', () {
    const tasks = [
      DayTask(taskId: 'a', title: 'الف', done: false, sort: 0),
      DayTask(taskId: 'b', title: 'ب', done: true, sort: 1),
      DayTask(taskId: 'c', title: 'ج', done: false, sort: 2),
    ];

    test('boulder and others split correctly', () {
      const plan = DayPlan(
        dayKey: '2026-07-07',
        planned: true,
        boulderId: 'a',
        prediction: 70,
        tasks: tasks,
        closed: false,
        outcome: null,
        whys: [],
        note: '',
      );
      expect(plan.boulder?.taskId, 'a');
      expect(plan.others.map((t) => t.taskId), ['b', 'c']);
      expect(plan.boulderDone, false);
    });

    test('boulderDone follows the boulder task state', () {
      const plan = DayPlan(
        dayKey: '2026-07-07',
        planned: true,
        boulderId: 'b',
        prediction: 50,
        tasks: tasks,
        closed: false,
        outcome: null,
        whys: [],
        note: '',
      );
      expect(plan.boulderDone, true);
    });

    test('empty plan has no boulder and is not planned', () {
      final plan = DayPlan.empty('2026-07-07');
      expect(plan.planned, false);
      expect(plan.boulder, isNull);
      expect(plan.others, isEmpty);
      expect(plan.boulderDone, false);
    });
  });

  group('ThoughtCategory', () {
    test('fromDb round-trips every category', () {
      for (final c in ThoughtCategory.values) {
        expect(ThoughtCategory.fromDb(c.db), c);
      }
    });

    test('fromDb falls back to idea on unknown value', () {
      expect(ThoughtCategory.fromDb('bogus'), ThoughtCategory.idea);
    });
  });
}
