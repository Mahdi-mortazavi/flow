import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/fa.dart';
import '../data/models.dart';
import '../data/repo.dart';

/// Local notifications: the end-of-focus alarm must fire even if the app is
/// killed, so it is scheduled on the OS at session start. Habit reminders
/// repeat daily at the anchor time and carry a one-tap «انجام شد» action.
/// The retention loop (morning plan / evening review / weekly mirror) also
/// lives on the OS scheduler so it works without the app running.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  static const _focusEndId = 1001;
  static const _morningId = 3001;
  static const _eveningId = 3002;
  static const _weeklyId = 3003;
  static const _habitDoneAction = 'habit_done';
  static const _habitCategory = 'habit_cue';
  static const _ember = Color(0xFFEFA55C);

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  /// Set by the UI to refresh providers after a notification action wrote to
  /// the database.
  void Function()? onHabitsChanged;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('ic_stat_dot');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _habitCategory,
          actions: [
            DarwinNotificationAction.plain(
              _habitDoneAction,
              'انجام شد ✓',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );
    // Never let a plugin/resource failure escape: a missing notification icon
    // or an OEM quirk must degrade notifications gracefully, not crash the
    // whole app (this runs during startup). Marked ready either way so we
    // don't spin retrying a permanent failure.
    try {
      await _plugin.initialize(
        settings: InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: _onResponse,
      );
    } catch (e, st) {
      debugPrint('Notifications.init failed (non-fatal): $e\n$st');
    }
    _ready = true;
  }

  Future<void> _onResponse(NotificationResponse response) =>
      _handleAction(response.actionId, response.payload);

  Future<void> _handleAction(String? actionId, String? payload) async {
    if (actionId == _habitDoneAction && payload != null && payload.isNotEmpty) {
      await Repo().logHabit(payload, todayKey(), 'done');
      onHabitsChanged?.call();
    }
  }

  /// Handles the case where tapping a notification action launched the app.
  Future<void> consumeLaunchAction() async {
    await init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      final r = details!.notificationResponse;
      if (r != null) await _handleAction(r.actionId, r.payload);
    }
  }

  Future<void> requestPermissions() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    // Android 12+: exact alarms need a user grant; the focus-end bell is the
    // whole point of the timer, so ask once up front.
    try {
      if (!(await android?.canScheduleExactNotifications() ?? true)) {
        await android?.requestExactAlarmsPermission();
      }
    } catch (_) {
      // Older plugin/OS combinations — inexact fallback covers us.
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Whether the focus-end alarm will ring on time (exact) or may drift.
  Future<bool> exactAlarmsAllowed() async {
    await init();
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.canScheduleExactNotifications() ??
          true;
    } catch (_) {
      return true;
    }
  }

  // ---------- focus end alarm ----------

  Future<void> scheduleFocusEnd(DateTime endAt, String taskTitle) async {
    await init();
    if (endAt.isBefore(DateTime.now())) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_end',
        'پایان تمرکز',
        channelDescription: 'اعلان پایان جلسه تمرکز',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        color: _ember,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
    final when = tz.TZDateTime.from(endAt, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: _focusEndId,
        title: 'زمان تمام شد',
        body: 'کمال‌گرایی را رها کن — «$taskTitle» را همین حالا ثبت کن.',
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Exact alarms denied — an inexact alarm is an acceptable fallback.
      await _plugin.zonedSchedule(
        id: _focusEndId,
        title: 'زمان تمام شد',
        body: 'کمال‌گرایی را رها کن — «$taskTitle» را همین حالا ثبت کن.',
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelFocusEnd() async {
    await init();
    await _plugin.cancel(id: _focusEndId);
  }

  // ---------- habit reminders ----------

  /// Stable notification id per habit (FNV-1a, kept positive and clear of
  /// the reserved ids).
  static int habitNotifId(String habitId) {
    var hash = 0x811c9dc5;
    for (final c in habitId.codeUnits) {
      hash = ((hash ^ c) * 0x01000193) & 0x7fffffff;
    }
    return 10000 + (hash % 100000000);
  }

  /// (Re)schedules the daily reminder at the habit's anchor time.
  Future<void> scheduleHabitReminder(Habit habit) async {
    await init();
    final id = habitNotifId(habit.id);
    final minutes = habit.reminderMinutes;
    if (minutes == null) {
      await _plugin.cancel(id: id);
      return;
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_cue',
        'یادآور عادت',
        channelDescription: 'یادآوری عادت در لحظه محرک',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        color: _ember,
        actions: [
          AndroidNotificationAction(
            _habitDoneAction,
            'انجام شد ✓',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        categoryIdentifier: _habitCategory,
      ),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: 'بعد از ${habit.cue}',
      body: habit.isBad
          ? 'مراقب باش — به‌جایش: ${habit.replacement.isEmpty ? 'دو دقیقه قدم بزن' : habit.replacement}'
          : '${habit.title} — نسخهٔ ۲ دقیقه‌ای هم قبول است.',
      scheduledDate: _nextOccurrence(minutes),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: habit.id,
    );
  }

  Future<void> cancelHabitReminder(String habitId) async {
    await init();
    await _plugin.cancel(id: habitNotifId(habitId));
  }

  /// Idempotent re-sync of all habit reminders (call at startup).
  Future<void> syncHabitReminders(List<Habit> habits) async {
    for (final h in habits) {
      await scheduleHabitReminder(h);
    }
  }

  // ---------- retention loop: morning / evening / weekly ----------

  tz.TZDateTime _nextOccurrence(int minutesOfDay, {bool skipToday = false}) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
    if (skipToday || !when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }

  static const _quietDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_ritual',
      'یادآور روزانه',
      channelDescription: 'یادآور چیدن صبح و مرور شب',
      color: _ember,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true),
  );

  /// Re-plans the morning/evening nudges around today's actual state:
  /// planned already → today's morning nudge is skipped; day closed →
  /// tonight's nudge is skipped. Repeats daily after the first fire.
  Future<void> syncDailyReminders({
    required bool plannedToday,
    required bool closedToday,
    required int? morningMinutes,
    required int? eveningMinutes,
  }) async {
    await init();
    await _plugin.cancel(id: _morningId);
    await _plugin.cancel(id: _eveningId);

    if (morningMinutes != null) {
      await _plugin.zonedSchedule(
        id: _morningId,
        title: 'روزت هنوز چیده نشده',
        body: 'سه کار، یک تخته‌سنگ، یک پیش‌بینی — کمتر از یک دقیقه.',
        scheduledDate: _nextOccurrence(morningMinutes, skipToday: plannedToday),
        notificationDetails: _quietDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
    if (eveningMinutes != null) {
      await _plugin.zonedSchedule(
        id: _eveningId,
        title: 'مرور شب',
        body: '۶۰ ثانیه: چک، چرا، یک خط — و روز بسته می‌شود.',
        scheduledDate: _nextOccurrence(eveningMinutes, skipToday: closedToday),
        notificationDetails: _quietDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    // Weekly mirror nudge — Friday 20:30, repeats weekly.
    final now = tz.TZDateTime.now(tz.local);
    var weekly = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 30);
    while (weekly.weekday != DateTime.friday || !weekly.isAfter(now)) {
      weekly = weekly.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _weeklyId,
      title: 'هفته تمام شد',
      body: 'یک نگاه به آینه بینداز — اعداد، قضاوت نیستند.',
      scheduledDate: weekly,
      notificationDetails: _quietDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}
