import 'package:shamsi_date/shamsi_date.dart';

const _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/// Converts every Latin digit in [value] to its Persian equivalent.
String faNum(Object value) => '$value'.replaceAllMapped(
  RegExp('[0-9]'),
  (m) => _faDigits[int.parse(m[0]!)],
);

/// mm:ss with Persian digits.
String faClock(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final mm = (s ~/ 60).toString().padLeft(2, '0');
  final ss = (s % 60).toString().padLeft(2, '0');
  return faNum('$mm:$ss');
}

/// Canonical day key (Gregorian, local time): yyyy-MM-dd.
String dayKeyOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String todayKey() => dayKeyOf(DateTime.now());

/// «سه‌شنبه، ۱۶ تیر» — Jalali date for the header.
String faTodayLabel() {
  final j = Jalali.now();
  final f = j.formatter;
  return '${f.wN}، ${faNum(j.day)} ${f.mN}';
}
