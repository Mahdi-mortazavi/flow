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

  // --- Common UI Actions & Labels ---
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

  static String retry(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تلاش دوباره' : 'Retry';

  static String next(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'بعدی' : 'Next';

  static String ok(AppLanguage lang) => lang == AppLanguage.fa ? 'باشه' : 'OK';

  static String set(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تنظیم' : 'Set';

  static String selectTime(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'انتخاب ساعت' : 'Select Time';

  static String checkLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'علامتِ انجام' : 'Mark as done';

  // --- Error Card ---
  static String errorTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'مشکلی پیش آمد' : 'Something went wrong';

  static String errorSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'داده‌هایت سر جایش است — فقط خواندنش خطا خورد.'
      : 'Your data is safe — reading it failed.';

  // --- Settings Screen ---
  static String settingsHeader(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآورها و پشتیبان' : 'Reminders & Backup';

  static String settingsSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'چرخهٔ روزانه بدون یادآور می‌میرد؛ داده بدون پشتیبان.'
      : 'The daily ritual dies without reminders; data dies without backup.';

  static String morningReminder(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآور صبح' : 'Morning Reminder';

  static String morningReminderSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'اگر روز هنوز چیده نشده باشد'
      : 'If the day is not planned yet';

  static String eveningReminder(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآور شب' : 'Evening Reminder';

  static String eveningReminderSub(AppLanguage lang) => lang == AppLanguage.fa
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

  static String appLanguage(AppLanguage lang) => lang == AppLanguage.fa
      ? 'زبان برنامه / App Language'
      : 'App Language / زبان برنامه';

  static String appLanguageSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تغییر زبان به فارسی یا انگلیسی'
      : 'Switch between Persian and English';

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

  static String confirmRestoreTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'بازیابی از پشتیبان؟' : 'Restore from backup?';

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

  // --- Today Screen & Tasks ---
  static String todayUnplannedTitle(AppLanguage lang) => lang == AppLanguage.fa
      ? 'امروز هنوز چیده نشده'
      : 'Today is not planned yet';

  static String todayUnplannedSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تخته‌سنگ و ۳ کار کلیدی را انتخاب کن تا روز شکل بگیرد.'
      : 'Choose The Boulder and up to 3 key tasks to shape your day.';

  static String planYourDay(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'برنامه‌ریزی روز' : 'Plan Your Day';

  static String readyForDeepFocus(AppLanguage lang) => lang == AppLanguage.fa
      ? 'برای تمرکز عمیق آماده‌ای؟'
      : 'Ready for deep focus?';

  static String startFocus(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'شروع تمرکز' : 'Start Focus';

  static String changeBoulder(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تغییر تخته‌سنگ' : 'Change Boulder';

  static String boulderUnlocksRest(AppLanguage lang) => lang == AppLanguage.fa
      ? 'با انجام تخته‌سنگ، بقیه کارها باز می‌شوند.'
      : 'Completing The Boulder unlocks the rest of your tasks.';

  static String unlockOtherTasksTitle(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'باز کردن قفل کارهای دیگر؟'
      : 'Unlock other tasks?';

  static String unlockOtherTasksSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تخته‌سنگ هنوز تمام نشده. تمرکز تک‌نقطه‌ای به خطر می‌افتد.'
      : 'The Boulder is not complete yet. Single-task focus will be disrupted.';

  static String unlockAnyway(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'به هر حال باز کن' : 'Unlock Anyway';

  static String returnToBoulder(AppLanguage lang) => lang == AppLanguage.fa
      ? 'نه، برگرد به تخته‌سنگ'
      : 'No, return to Boulder';

  static String deleteTaskTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'حذف کار؟' : 'Delete task?';

  static String deleteTaskSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'این کار از امروز و مخزن کارهای انجام‌نشده حذف می‌شود.'
      : 'This task will be removed from today and the backlog.';

  static String editTitleAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ویرایش عنوان' : 'Edit Title';

  static String removeFromTodayAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'حذف از امروز' : 'Remove from Today';

  static String closeDay(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'بستن روز' : 'Close Day';

  static String dumpThought(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ثبت فکر' : 'Capture Thought';

  // --- Guilt-Free Fun Block ---
  static String funLockedSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'قفل تا سقوط تخته‌سنگ'
      : 'Locked until The Boulder falls';

  static String funUnlockedSub(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'آزاد و سزاوار' : 'Unlocked & Earned';

  static String funHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تخته‌سنگ که بیفتد، تفریح بدون احساس گناه آغاز می‌شود.'
      : 'Once The Boulder falls, guilt-free play begins.';

  static String configFunTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تنظیم تفریح' : 'Configure Play Block';

  static String configFunPrompt(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تفریح امروزت چیست؟'
      : 'What is your play block today?';

  static String configFunHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'مثلاً: دو قسمت سریال، گیم، پیاده‌روی بدون گوشی'
      : 'e.g., Two episodes, gaming, walk without phone';

  static String durationMinutes(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'مدت زمان (دقیقه)' : 'Duration (minutes)';

  // --- Active Habits ---
  static String addHabit(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'افزودن عادت' : 'Add Habit';

  static String noHabitsTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عادتی ثبت نشده' : 'No habits set';

  static String noHabitsSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'یک عادت روزانه بساز تا زنجیره شکل بگیرد.'
      : 'Create a daily habit to build momentum.';

  static String anchorCueLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'نشانه' : 'Anchor Cue';

  static String badHabitTag(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عادت بد' : 'Bad Habit';

  static String resistedTag(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'مقاومت شد ✓' : 'Resisted ✓';

  static String faceFrictionAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'مواجهه با اصطکاک' : 'Face Friction';

  // --- Task Edit Sheet ---
  static String editTaskTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ویرایش کار' : 'Edit Task';

  static String editTaskSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'عنوان کار را اصلاح کن یا آن را کلاً کنار بگذار.'
      : 'Refine the task title or discard it altogether.';

  static String taskTitleLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عنوان کار' : 'Task Title';

  static String deleteTaskAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'حذف کار' : 'Delete Task';

  // --- Evening Review Sheet ---
  static String eveningReviewTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'پایان روز' : 'Evening Review';

  static String eveningReviewDoneSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تخته‌سنگ افتاد. روز را ببند و ذهن را خالی کن.'
      : 'The Boulder fell. Close the day and clear your mind.';

  static String eveningReviewMissedSub(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'تخته‌سنگ نیفتاد — سیستم شکست خورد، نه تو. علل را تفکیک کن.'
      : 'The Boulder didn\'t fall — the system failed, not you. Trace the root causes.';

  static String whyLabel(int index, AppLanguage lang) {
    if (lang == AppLanguage.fa) {
      return index == 0
          ? 'چرا اول (علت ریشه‌ای)'
          : index == 1
          ? 'چرا دوم'
          : 'چرا سوم';
    }
    return index == 0
        ? 'Why 1 (Systemic Cause)'
        : index == 1
        ? 'Why 2'
        : 'Why 3';
  }

  static String whyHint(int index, AppLanguage lang) {
    if (lang == AppLanguage.fa) {
      return index == 0
          ? 'چرا تخته‌سنگ انجام نشد؟'
          : index == 1
          ? 'چرا این اتفاق افتاد؟'
          : 'چرا سیستم نتوانست جلویش را بگیرد؟';
    }
    return index == 0
        ? 'Why didn\'t The Boulder get done?'
        : index == 1
        ? 'Why did that happen?'
        : 'Why couldn\'t the system prevent it?';
  }

  static String addDeeperWhy(AppLanguage lang) =>
      lang == AppLanguage.fa ? '+ یک «چرا»ی عمیق‌تر' : '+ A deeper \'Why\'';

  static String nightNoteLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادداشت یک‌خطی شب' : 'One-line Night Note';

  static String nightNoteHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'یک جمله دربارهٔ امروز…'
      : 'One sentence about today...';

  static String confirmCloseDayAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تثبیت و بستن روز' : 'Confirm & Close Day';

  static String toastRecordedWinningDay(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ثبت شد. روزِ برنده.' : 'Recorded. Winning day.';

  static String toastRecordedImprovedSystem(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'ثبت شد. فردا با سیستمِ اصلاح‌شده.'
      : 'Recorded. Tomorrow with an improved system.';

  static String toastAtLeastOneWhy(AppLanguage lang) => lang == AppLanguage.fa
      ? 'حداقل یک «چرا» — همین‌جا یادگیری اتفاق می‌افتد'
      : 'At least one \'Why\' — this is where learning happens';

  // --- Focus Screen ---
  static String deepFocusTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تمرکز عمیق' : 'Deep Focus';

  static String deepFocusSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'فقط و فقط یک کار.'
      : 'One thing and one thing only.';

  static String endFocusAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'پایان تمرکز' : 'End Focus';

  static String earlyEndTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'پایان زودهنگام تمرکز؟' : 'End focus early?';

  static String interruptNoteLabel(AppLanguage lang) => lang == AppLanguage.fa
      ? 'علت وقفه (اختیاری)'
      : 'Interruption reason (optional)';

  static String interruptTagLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'برچسب وقفه' : 'Interruption Tag';

  static String recordAndEndAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ثبت و پایان' : 'Record & End';

  static String continueFocusAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ادامه تمرکز' : 'Continue Focus';

  static String tagExternal(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'بیرونی (تماس/پیام)' : 'External (Call/Msg)';

  static String tagInternal(AppLanguage lang) => lang == AppLanguage.fa
      ? 'درونی (وسوسه/حواس‌پرتی)'
      : 'Internal (Impulse/Distraction)';

  static String tagFatigue(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'خستگی/افت انرژی' : 'Fatigue/Low Energy';

  static String tagUnexpected(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'کار غیرمنتظره' : 'Unexpected Task';

  static String timeUpTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'زمان تمرکز تمام شد' : 'Focus Time Expired';

  static String isBoulderDone(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تخته‌سنگ تمام شد؟' : 'Is The Boulder done?';

  static String yesDone(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'بله، انجام شد ✓' : 'Yes, Done ✓';

  static String addTenMinFocus(AppLanguage lang) =>
      lang == AppLanguage.fa ? '+ ۱۰ دقیقه ادامه' : '+ 10 Min Focus';

  static String notYet(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'هنوز نه' : 'Not Yet';

  // --- Bad Habit Friction Sheet ---
  static String frictionTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'اصطکاک عادت بد' : 'Bad Habit Friction';

  static String mindfulPauseSeconds(int s, AppLanguage lang) =>
      lang == AppLanguage.fa
      ? '${fmtNum(s, lang)} ثانیه مکث آگاهانه…'
      : '$s-second Mindful Pause...';

  static String rememberCostSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'هزینه این رفتار را به یاد بیاور:'
      : 'Remember the cost of this behavior:';

  static String costLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'هزینه' : 'Cost';

  static String replacementLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'جایگزین پیشنهادی:' : 'Suggested Replacement:';

  static String slippedAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تسلیم شدم (ثبت لغزش)' : 'Slipped (Log Slip)';

  static String resistedAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'مقاومت کردم ✓' : 'Resisted ✓';

  static String toastSlipped(AppLanguage lang) => lang == AppLanguage.fa
      ? 'ثبت شد. اشکالی ندارد — دوباره شروع کن.'
      : 'Logged. It\'s okay — reset and try again.';

  static String toastResisted(AppLanguage lang) => lang == AppLanguage.fa
      ? 'آفرین! یک پیروزی برای کنترل اراده.'
      : 'Bravo! A win for self-control.';

  // --- Habit Editor ---
  static String newHabitTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عادت جدید' : 'New Habit';

  static String editHabitTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ویرایش عادت' : 'Edit Habit';

  static String habitEditorSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'رفتارهای کوچک روزانه، هویت آینده‌ات را می‌سازند.'
      : 'Small daily behaviors forge your future identity.';

  static String positiveHabitType(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عادت مثبت' : 'Positive Habit';

  static String badHabitType(AppLanguage lang) => lang == AppLanguage.fa
      ? 'عادت بد (نیاز به اصطکاک)'
      : 'Bad Habit (Friction Needed)';

  static String habitTitleLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عنوان عادت' : 'Habit Title';

  static String habitTitleHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'مثلاً: خواندن ۱۰ صفحه کتاب'
      : 'e.g., Read 10 pages of a book';

  static String cueLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'نشانه / محرک (Anchor Cue)' : 'Anchor Cue';

  static String cueHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'مثلاً: بعد از قهوه صبح'
      : 'e.g., After morning coffee';

  static String reminderTimeOptional(AppLanguage lang) => lang == AppLanguage.fa
      ? 'ساعت یادآور (اختیاری)'
      : 'Reminder Time (Optional)';

  static String badCostLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'هزینه عادت بد' : 'Cost of Bad Habit';

  static String badCostHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'مثلاً: افت انرژی و پشیمانی'
      : 'e.g., Energy crash and regret';

  static String replacementInputLabel(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'جایگزین مثبت' : 'Positive Replacement';

  static String replacementInputHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'مثلاً: ۱۰ لیوان آب یا ۵ کشش'
      : 'e.g., Drink water or 5 stretches';

  static String deleteHabitAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'حذف عادت' : 'Delete Habit';

  // --- Onboarding Screen ---
  static String onboardingSlide1Title(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تک‌نقطه' : 'Flow';

  static String onboardingSlide1Sub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تمرکز عمیق روی یک تخته‌سنگ در روز.'
      : 'Deep focus on one Boulder a day.';

  static String onboardingSlide1Body(AppLanguage lang) => lang == AppLanguage.fa
      ? 'چندکارگی فقط وهمِ بهره‌وری است. تک‌نقطه ذهنت را روی مهم‌ترین هدف روز قفل می‌کند.'
      : 'Multitasking is an illusion of productivity. Flow locks your mind onto today\'s single most critical goal.';

  static String onboardingSlide2Title(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'اصطکاک و کالیبراسیون'
      : 'Friction & Calibration';

  static String onboardingSlide2Sub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'پیش‌بینی خوش‌بینی و مدیریت عادت‌ها.'
      : 'Optimism calibration & habit friction.';

  static String onboardingSlide2Body(AppLanguage lang) => lang == AppLanguage.fa
      ? 'با کالیبره‌کردن پیش‌بینی موفقیت و ایجاد اصطکاک روی عادت‌های بد، کنترلت را روی وقتت پس بگیر.'
      : 'By calibrating success predictions and adding friction to bad habits, reclaim total control over your time.';

  static String onboardingSlide3Title(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآورهای هوشمند' : 'Smart Reminders';

  static String onboardingSlide3Sub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'ساعتِ شروع و بستن روزت را تنظیم کن.'
      : 'Set your daily kickoff and review times.';

  static String startFlowAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'شروع تک‌نقطه' : 'Start Flow';

  // --- Weekly Review Sheet ---
  static String weeklyReviewTitle(AppLanguage lang) => lang == AppLanguage.fa
      ? 'مرور هفتگی (Zero-Based)'
      : 'Weekly Review (Zero-Based)';

  static String weeklyReviewSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تصفیهٔ کامل هفتهٔ گذشته و کالیبراسیون آینده.'
      : 'Clear out the past week and calibrate for the future.';

  static String winRateCardTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'نرخ پیروزی تخته‌سنگ' : 'Boulder Win Rate';

  static String primaryInterruptionPattern(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'الگوی وقفه اصلی'
      : 'Primary Interruption Pattern';

  static String completeWeeklyReviewAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'پایان مرور هفتگی' : 'Complete Weekly Review';

  // --- Performance Mirror (Stats Screen) ---
  static String performanceMirrorTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'آینه عملکرد' : 'Performance Mirror';

  static String realityWithoutJudgment(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'واقعیت بدون قضاوت.'
      : 'Reality without judgment.';

  static String focusStatsTab(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'آمار تمرکز' : 'Focus Stats';

  static String patternsTab(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'الگوها' : 'Patterns';

  static String winRateSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'روزهایی که تخته‌سنگ افتاد'
      : 'Days The Boulder fell';

  static String optimismGapSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'تفاوت پیش‌بینی و واقعیت'
      : 'Difference between prediction and reality';

  static String recoveryRateSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'بازگشت سریع بعد از شکست'
      : 'Bouncing back after a miss';

  static String goldenHourSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'بهترین بازه زمانی تمرکز تو'
      : 'Your peak focus time window';

  static String last7DaysFocusChartTitle(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'تمرکز ۷ روز گذشته (دقیقه)'
      : 'Last 7 Days Focus (Minutes)';

  static String rankedPatterns30DaysTitle(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'رتبه‌بندی وقایع و وقفه‌ها (۳۰ روز)'
      : 'Ranked Interruptions & Patterns (30 Days)';

  static String weeklyReviewBannerTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'زمان مرور هفتگی' : 'Time for Weekly Review';

  static String weeklyReviewBannerSub(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? '۶ روز گذشته بسته‌شده — آینه برای جمع‌بندی آماده است.'
      : '6 days recorded — the mirror is ready for summary.';

  static String startWeeklyReviewAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'شروع مرور هفتگی' : 'Start Weekly Review';

  // --- Brain Vault Sheet ---
  static String brainVaultSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'افکارت را تخلیه کن تا ذهنت آزاد شود.'
      : 'Dump thoughts to free your mind.';

  static String vaultInputHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'یک فکر، ایده یا نگرانی…'
      : 'A thought, idea, or worry...';

  static String filterAll(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'همه' : 'All';

  static String filterIdea(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ایده' : 'Idea';

  static String filterWorry(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'نگرانی' : 'Worry';

  static String filterTask(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'کاری' : 'Task';

  static String emptyVaultTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'مخزن خالی است' : 'Vault is empty';

  static String emptyVaultSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'هر فکری که چنگ می‌زند را اینجا بریز.'
      : 'Dump any distracting thought here.';

  static String promoteToTodayAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ارتقا به امروز' : 'Promote to Today';

  static String toastPromotedToToday(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'به امروز منتقل شد' : 'Promoted to Today';

  static String toastThoughtDeleted(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'فکر حذف شد' : 'Thought deleted';

  // --- Morning Wizard ---
  static String morningSetupTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'برنامه‌ریزی صبحگاهی' : 'Morning Setup';

  static String morningSetupSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'حداکثر ۳ کار انتخاب کن. یکی را تخته‌سنگ بگذار.'
      : 'Select up to 3 tasks. Set one as The Boulder.';

  static String newTaskHint(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'کار جدید…' : 'New task...';

  static String predictionSliderLabel(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'پیش‌بینی احتمال موفقیت امروزد:'
      : 'Predicted probability of success today:';

  static String selectTodayBoulderLabel(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'تخته‌سنگ امروزت کدام است؟'
      : 'Which one is today\'s Boulder?';

  static String confirmAndStartDayAction(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'ثبت و شروع روز' : 'Confirm & Start Day';

  static String toastEnterAtLeastOneTask(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'حداقل یک کار وارد کن' : 'Add at least one task';

  // --- Additional UI Getters ---
  static String boulderOfToday(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تخته‌سنگِ امروز' : 'Today\'s Boulder';

  static String otherTwoTasks(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'دو کارِ دیگر' : 'Other Two Tasks';

  static String todayNotPlannedYet(AppLanguage lang) => lang == AppLanguage.fa
      ? 'امروز هنوز چیده نشده. سه کار، یک تخته‌سنگ، یک پیش‌بینی — کمتر از یک دقیقه.'
      : 'Today is not planned yet. Three tasks, one Boulder, one prediction — under one minute.';

  static String planToday(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'چیدنِ امروز' : 'Plan Today';

  static String boulderTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'تخته‌سنگ' : 'The Boulder';

  static String queuedBehindBoulder(AppLanguage lang) => lang == AppLanguage.fa
      ? 'پشتِ تخته‌سنگ در صف'
      : 'Queued behind The Boulder';

  static String eveningReviewSub(AppLanguage lang) => lang == AppLanguage.fa
      ? '۶۰ ثانیه — چک، چرا، یک خط'
      : '60 seconds — check, why, one line';

  static String habitsTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عادت‌ها' : 'Habits';

  static String habitTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'عادت' : 'Habit';

  static String thoughtHint(AppLanguage lang) => lang == AppLanguage.fa
      ? 'فکر یا ایده‌ات را بنویس…'
      : 'Type your thought or idea...';

  static String searchHint(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'جستجو…' : 'Search...';

  static String noResultsFound(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'نتیجه‌ای یافت نشد.' : 'No results found.';

  static String dayPlannedToast(AppLanguage lang) => lang == AppLanguage.fa
      ? 'روز چیده شد. حالا فقط اجرا.'
      : 'Day planned. Now focus and execute.';

  static String morningPlanHeader(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'برنامهٔ امروز' : 'Today\'s Plan';

  static String morningPlanSub(AppLanguage lang) => lang == AppLanguage.fa
      ? 'حداکثر ۳ کار انتخاب کن، بعد مهم‌ترین را با ستاره «تخته‌سنگ» کن — کاری که اگر فقط همان انجام شود، امروز برنده است.'
      : 'Select up to 3 tasks, then star the most important one as "The Boulder" — the task that makes today a win.';

  static String startDay(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'شروع روز' : 'Start Day';

  static String boulderProbabilityQuestion(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'چند درصد احتمال می‌دهی تخته‌سنگ را امروز تمام کنی؟ صادق باش — شب چک می‌شود.'
      : 'What probability percentage do you give to finish The Boulder today? Be honest — reviewed tonight.';

  // --- Active Days Task Capacity Progression ---
  static String pebbleTag(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'سنگریزه' : 'Pebble';

  static String pebbleHelperText(AppLanguage lang) => lang == AppLanguage.fa
      ? 'کار سریع و کم‌انرژی (زیر ۱۵ دقیقه)'
      : 'Quick win (<15 min low-energy task)';

  static String activeDaysProgressHint(
    int activeDays,
    int maxTasks,
    AppLanguage lang,
  ) {
    if (activeDays < 15) {
      return lang == AppLanguage.fa
          ? '${fmtNum(activeDays, lang)}/۱۵ روز فعال برای باز کردن ظرفیت ۴ام'
          : '${fmtNum(activeDays, lang)}/15 active days to unlock 4th task slot';
    } else if (activeDays < 30) {
      return lang == AppLanguage.fa
          ? '${fmtNum(activeDays, lang)}/۳۰ روز فعال برای باز کردن ظرفیت ۵ام'
          : '${fmtNum(activeDays, lang)}/30 active days to unlock 5th task slot';
    } else {
      return lang == AppLanguage.fa
          ? 'ظرفیت حداکثری باز شد (۵ کار)'
          : 'Max capacity unlocked (5 tasks)';
    }
  }

  static String maxTasksReachedToast(int maxTasks, AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'حداکثر ${fmtNum(maxTasks, lang)} کار بر اساس روزهای فعال'
      : 'Max ${fmtNum(maxTasks, lang)} tasks based on active days';

  static String otherTasksHeader(int count, AppLanguage lang) {
    if (lang == AppLanguage.fa) {
      return count == 2 ? 'دو کارِ دیگر' : 'سایر کارها و سنگریزه‌ها';
    }
    return count == 2 ? 'Other Two Tasks' : 'Secondary Tasks & Pebbles';
  }

  // --- Notifications Localizations ---
  static String focusEndChannelName(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'پایان تمرکز' : 'Focus Session Ended';

  static String focusEndTimeUpTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'زمان تمام شد' : 'Time is up';

  static String focusEndTimeUpBody(String taskTitle, AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'کمال‌گرایی را رها کن — «$taskTitle» را همین حالا ثبت کن.'
      : 'Let go of perfectionism — record "$taskTitle" right now.';

  static String habitNotificationChannelName(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآور عادت' : 'Habit Reminder';

  static String habitNotificationActionDone(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'انجام شد ✓' : 'Mark Done ✓';

  static String habitNotificationCueTitle(String cue, AppLanguage lang) =>
      lang == AppLanguage.fa ? 'بعد از $cue' : 'After $cue';

  static String habitNotificationBody({
    required bool isBad,
    required String title,
    required String replacement,
    required AppLanguage lang,
  }) {
    if (lang == AppLanguage.fa) {
      return isBad
          ? 'مراقب باش — به‌جایش: ${replacement.isEmpty ? 'دو دقیقه قدم بزن' : replacement}'
          : '$title — نسخهٔ ۲ دقیقه‌ای هم قبول است.';
    }
    return isBad
        ? 'Watch out — instead: ${replacement.isEmpty ? 'take a 2-minute walk' : replacement}'
        : '$title — the 2-minute version counts too.';
  }

  static String dailyRitualChannelName(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'یادآور روزانه' : 'Daily Ritual Nudge';

  static String morningNotificationTitle(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'روزت هنوز چیده نشده'
      : 'Your day is not planned yet';

  static String morningNotificationBody(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'سه کار، یک تخته‌سنگ، یک پیش‌بینی — کمتر از یک دقیقه.'
      : 'Three tasks, one Boulder, one prediction — under one minute.';

  static String eveningNotificationTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'مرور شب' : 'Evening Review';

  static String eveningNotificationBody(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? '۶۰ ثانیه: چک، چرا، یک خط — و روز بسته می‌شود.'
      : '60 seconds: check, why, one line — and the day is closed.';

  static String weeklyNotificationTitle(AppLanguage lang) =>
      lang == AppLanguage.fa ? 'هفته تمام شد' : 'Week completed';

  static String weeklyNotificationBody(AppLanguage lang) =>
      lang == AppLanguage.fa
      ? 'یک نگاه به آینه بینداز — اعداد، قضاوت نیستند.'
      : 'Take a look in the mirror — metrics are not judgment.';
}
