import 'package:flutter/material.dart';

import 'fa.dart';

/// Supported application languages.
enum AppLanguage {
  fa('fa', 'فارسی', TextDirection.rtl),
  en('en', 'English', TextDirection.ltr);

  final String code;
  final String label;
  final TextDirection direction;

  const AppLanguage(this.code, this.label, this.direction);

  static AppLanguage fromCode(String? code) {
    return code == 'en' ? AppLanguage.en : AppLanguage.fa;
  }
}

/// Locale-aware string translations and formatting helpers for taknoghte/flow.
/// Maintains the behavioral science, psychological depth, and liquid-glass tone
/// in both Persian and English.
abstract final class L10n {
  /// Converts [value] digits based on the active language.
  static String fmtNum(Object value, AppLanguage lang) {
    return lang == AppLanguage.fa ? faNum(value) : '$value';
  }

  /// Formats total seconds as mm:ss with language-appropriate digits.
  static String fmtClock(int totalSeconds, AppLanguage lang) {
    final s = totalSeconds < 0 ? 0 : totalSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return fmtNum('$mm:$ss', lang);
  }

  /// Short day label (e.g., «۱۶ تیر» in Persian, "Jul 16" in English).
  static String fmtDayLabel(String dayKey, AppLanguage lang) {
    if (lang == AppLanguage.fa) {
      return faDayLabel(dayKey);
    }
    final parts = dayKey.split('-').map(int.parse).toList();
    final dt = DateTime(parts[0], parts[1], parts[2]);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  /// Header date label (e.g., «سه‌شنبه، ۱۶ تیر» in Persian, "Tuesday, Jul 16" in English).
  static String fmtTodayLabel(AppLanguage lang) {
    if (lang == AppLanguage.fa) {
      return faTodayLabel();
    }
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final w = days[now.weekday - 1];
    final m = months[now.month - 1];
    return '$w, $m ${now.day}';
  }

  // --- App & Core Navigation ---
  static String appTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تک‌نقطه' : 'Flow';

  static String todayTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'امروز' : 'Today';

  static String statsMirrorTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'آینه' : 'Stats Mirror';

  static String brainVaultTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'مخزن ذهن' : 'Brain Vault';

  static String settingsTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تنظیمات' : 'Settings';

  // --- Core Concepts & Terms ---
  static String theBoulder(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تخته‌سنگ' : 'The Boulder';

  static String prediction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'پیش‌بینی' : 'Prediction';

  static String optimismGap(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'شکاف خوش‌بینی' : 'Optimism Gap';

  static String winRate(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'نرخ پیروزی' : 'Win Rate';

  static String recoveryRate(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'نرخ بازگشت' : 'Recovery Rate';

  static String goldenHour(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ساعت طلایی' : 'Golden Hour';

  static String energyCheckIn(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'چک‌این انرژی' : 'Energy Check-in';

  static String guiltFreePlayBlock(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'بلوک تفریح بدون گناه' : 'Guilt-Free Play Block';

  static String activeHabits(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عادت‌های فعال' : 'Active Habits';

  static String badHabitFriction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'اصطکاک عادت بد' : 'Bad Habit Friction';

  // --- Settings Screen ---
  static String settingsHeader(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآورها و پشتیبان' : 'Reminders & Backup';

  static String settingsSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'چرخهٔ روزانه بدون یادآور می‌میرد؛ داده بدون پشتیبان.'
      : 'The daily ritual dies without reminders; data dies without backup.';

  static String morningReminder(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآور صبح' : 'Morning Reminder';

  static String morningReminderSub(AppLanguage lang) =>
      lang == AppLanguage.fa
          ? 'اگر روز هنوز چیده نشده باشد'
          : 'If the day is not planned yet';

  static String eveningReminder(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآور شب' : 'Evening Reminder';

  static String eveningReminderSub(AppLanguage lang) =>
      lang == AppLanguage.fa
          ? 'اگر روز هنوز بسته نشده باشد'
          : 'If the day is not closed yet';

  static String exportBackup(AppLanguage lang) => lang == AppLanguage.fa
      ? 'پشتیبان‌گیری (خروجی JSON)'
      : 'Backup Data (JSON Export)';

  static String exportBackupSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'همهٔ داده‌ها در یک فایل — هر جا خواستی نگهش دار'
      : 'All data in one single file — store it anywhere you like';

  static String restoreBackup(AppLanguage lang) => lang == AppLanguage.fa
      ? 'بازیابی از فایل پشتیبان'
      : 'Restore from Backup';

  static String restoreBackupSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'جایگزینی کامل داده‌های فعلی'
      : 'Complete replacement of current data';

  static String appLanguage(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'زبان برنامه / App Language' : 'App Language / زبان برنامه';

  static String appLanguageSub(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تغییر زبان به فارسی یا انگلیسی' : 'Switch between Persian and English';

  static String batterySettings(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآورها نمی‌آیند؟' : 'Reminders not arriving?';

  static String batterySettingsSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'در برخی گوشی‌ها (شیائومی، هواوی…) باید اپ را از بهینه‌سازی باتری مستثنا کنی'
      : 'On some devices (Xiaomi, Huawei...), exclude the app from battery optimization';

  static String off(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'خاموش' : 'Off';

  static String turnOn(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'روشن کردن' : 'Turn On';

  static String turnOff(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'خاموش کردن' : 'Turn Off';

  static String confirmRestoreTitle(AppLanguage lang) => lang == AppLanguage.fa
      ? 'بازیابی از پشتیبان؟'
      : 'Restore from backup?';

  static String confirmRestoreSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'همهٔ داده‌های فعلی با محتوای فایل جایگزین می‌شود. این عمل قابل برگشت نیست.'
      : 'All current data will be replaced with file contents. This action cannot be undone.';

  static String replaceAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'جایگزین کن' : 'Replace';

  static String restoreSuccess(AppLanguage lang) => lang == AppLanguage.fa
      ? 'بازیابی انجام شد'
      : 'Restoration completed successfully';

  static String invalidBackupFile(AppLanguage lang) => lang == AppLanguage.fa
      ? 'این فایل، پشتیبانِ تک‌نقطه نیست'
      : 'This file is not a valid Flow backup';

  // --- Common UI Actions ---
  static String cancel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'انصراف' : 'Cancel';

  static String confirm(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تأیید' : 'Confirm';

  static String save(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ذخیره' : 'Save';

  static String delete(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'حذف' : 'Delete';

  static String edit(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ویرایش' : 'Edit';

  static String close(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'بستن' : 'Close';

  static String undo(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'لغو' : 'Undo';
}
