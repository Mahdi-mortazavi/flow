import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/fa.dart';
import '../data/models.dart';
import '../data/repo.dart';

/// Local notifications: the end-of-focus alarm must fire even if the app is
/// killed, so it is scheduled on the OS at session start. Habit reminders
/// repeat daily at the anchor time and carry a one-tap «انجام شد» action.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  static const _focusEndId = 1001;
  static const _habitDoneAction = 'habit_done';

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  /// Set by the UI to refresh providers after a notification action wrote to
  /// the database.
  void Function()? onHabitsChanged;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onResponse,
    );
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
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
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
      // Exact alarms may be denied on Android 12+; an inexact alarm is
      // acceptable for a focus timer.
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
  /// the reserved focus id).
  static int habitNotifId(String habitId) {
    var hash = 0x811c9dc5;
    for (final c in habitId.codeUnits) {
      hash = ((hash ^ c) * 0x01000193) & 0x7fffffff;
    }
    return 2000 + (hash % 100000000);
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
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_cue',
        'یادآور عادت',
        channelDescription: 'یادآوری عادت در لحظه محرک',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: [
          AndroidNotificationAction(
            _habitDoneAction,
            'انجام شد ✓',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(presentAlert: true),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: 'بعد از ${habit.cue}',
      body: habit.isBad
          ? 'مراقب باش — به‌جایش: ${habit.replacement.isEmpty ? 'دو دقیقه قدم بزن' : habit.replacement}'
          : '${habit.title} — نسخهٔ ۲ دقیقه‌ای هم قبول است.',
      scheduledDate: when,
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
}
