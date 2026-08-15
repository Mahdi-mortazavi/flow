import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taknoghte/core/l10n.dart';
import 'package:taknoghte/data/database.dart';
import 'package:taknoghte/data/models.dart';
import 'package:taknoghte/data/repo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Active Days Task Capacity Progression Logic', () {
    test('maxTasksForActiveDays calculates capacity tiers and caps at 5', () {
      expect(maxTasksForActiveDays(0), 3);
      expect(maxTasksForActiveDays(7), 3);
      expect(maxTasksForActiveDays(14), 3);

      expect(maxTasksForActiveDays(15), 4);
      expect(maxTasksForActiveDays(20), 4);
      expect(maxTasksForActiveDays(29), 4);

      expect(maxTasksForActiveDays(30), 5);
      expect(maxTasksForActiveDays(50), 5);
      expect(maxTasksForActiveDays(100), 5);
    });

    test('L10n hints and tags support Persian and English', () {
      expect(L10n.pebbleTag(AppLanguage.fa), 'سنگریزه');
      expect(L10n.pebbleTag(AppLanguage.en), 'Pebble');

      expect(
        L10n.pebbleHelperText(AppLanguage.fa),
        'کار سریع و کم‌انرژی (زیر ۱۵ دقیقه)',
      );
      expect(
        L10n.pebbleHelperText(AppLanguage.en),
        'Quick win (<15 min low-energy task)',
      );

      expect(
        L10n.activeDaysProgressHint(12, 3, AppLanguage.fa),
        '۱۲/۱۵ روز فعال برای باز کردن ظرفیت ۴ام',
      );
      expect(
        L10n.activeDaysProgressHint(12, 3, AppLanguage.en),
        '12/15 active days to unlock 4th task slot',
      );

      expect(
        L10n.activeDaysProgressHint(22, 4, AppLanguage.fa),
        '۲۲/۳۰ روز فعال برای باز کردن ظرفیت ۵ام',
      );
      expect(
        L10n.activeDaysProgressHint(22, 4, AppLanguage.en),
        '22/30 active days to unlock 5th task slot',
      );

      expect(
        L10n.activeDaysProgressHint(35, 5, AppLanguage.fa),
        'ظرفیت حداکثری باز شد (۵ کار)',
      );
      expect(
        L10n.activeDaysProgressHint(35, 5, AppLanguage.en),
        'Max capacity unlocked (5 tasks)',
      );
    });
  });

  group('Database Active Days & Capacity Persistence', () {
    late Repo repo;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      AppDatabase.fileName =
          'test_active_days_${DateTime.now().microsecondsSinceEpoch}.db';
      repo = Repo();
    });

    test('activeDaysCount counts total closed days non-punitively', () async {
      expect(await repo.activeDaysCount(), 0);

      // Plan day 1 & close it
      final b1 = await repo.addBacklog('Boulder 1');
      await repo.planDay(
        dayKey: '2026-08-01',
        selected: [b1],
        boulderId: b1.id,
        prediction: 80,
      );
      await repo.closeDay(
        dayKey: '2026-08-01',
        whys: ['All good'],
        note: 'Solid day',
      );

      expect(await repo.activeDaysCount(), 1);

      // Gap of 3 days (non-consecutive) — miss should NOT reset progress!
      final b2 = await repo.addBacklog('Boulder 2');
      await repo.planDay(
        dayKey: '2026-08-05',
        selected: [b2],
        boulderId: b2.id,
        prediction: 90,
      );
      await repo.closeDay(
        dayKey: '2026-08-05',
        whys: [],
        note: 'Back after gap',
      );

      expect(await repo.activeDaysCount(), 2);
    });
  });
}
