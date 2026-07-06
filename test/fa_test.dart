import 'package:flutter_test/flutter_test.dart';
import 'package:taknoghte/core/fa.dart';

void main() {
  group('faNum', () {
    test('converts all Latin digits to Persian', () {
      expect(faNum(1234567890), '۱۲۳۴۵۶۷۸۹۰');
    });

    test('leaves non-digit characters untouched', () {
      expect(faNum('پیش‌بینی 70٪'), 'پیش‌بینی ۷۰٪');
    });

    test('handles zero and negative numbers', () {
      expect(faNum(0), '۰');
      expect(faNum(-5), '-۵');
    });
  });

  group('faClock', () {
    test('formats mm:ss with Persian digits', () {
      expect(faClock(0), '۰۰:۰۰');
      expect(faClock(59), '۰۰:۵۹');
      expect(faClock(60), '۰۱:۰۰');
      expect(faClock(25 * 60), '۲۵:۰۰');
      expect(faClock(90 * 60 - 1), '۸۹:۵۹');
    });

    test('clamps negative seconds to zero', () {
      expect(faClock(-10), '۰۰:۰۰');
    });
  });

  group('dayKeyOf', () {
    test('pads month and day to two digits', () {
      expect(dayKeyOf(DateTime(2026, 7, 7)), '2026-07-07');
      expect(dayKeyOf(DateTime(2026, 12, 31)), '2026-12-31');
      expect(dayKeyOf(DateTime(2026)), '2026-01-01');
    });

    test('todayKey matches dayKeyOf(now)', () {
      expect(todayKey(), dayKeyOf(DateTime.now()));
    });
  });
}
