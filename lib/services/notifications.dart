import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/fa.dart';
import '../core/l10n.dart';
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
  static const _taskCategory = 'task_reminder';
  static const _taskFocusAction = 'task_focus';
  static const _taskDoneAction = 'task_done';
  static const _ember = Color(0xFFEFA55C);

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  /// Set by the UI to refresh providers after a notification action wrote to
  /// the database.
  void Function()? onHabitsChanged;

  /// Triggered when the user taps a task reminder notification or action.
  void Function(String taskId, String? actionId)? onTaskLaunch;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final timeZoneName = info.identifier;
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        final loc = tz.timeZoneDatabase.locations[timeZoneName];
        if (loc != null) {
          tz.setLocalLocation(loc);
        }
      }
    } catch (e) {
      debugPrint('Notifications.init timezone detection failed: $e');
    }
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
              '✓',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
        DarwinNotificationCategory(
          _taskCategory,
          actions: [
            DarwinNotificationAction.plain(
              _taskFocusAction,
              'Focus',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              _taskDoneAction,
              'Done',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );
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
    if (payload == null || payload.isEmpty) return;
    if (actionId == _habitDoneAction || payload.startsWith('habit:')) {
      final habitId = payload.replaceFirst('habit:', '');
      await Repo().logHabit(habitId, todayKey(), 'done');
      onHabitsChanged?.call();
    } else if (payload.startsWith('task:')) {
      final taskId = payload.replaceFirst('task:', '');
      if (actionId == _taskDoneAction) {
        await Repo().setTaskDone(todayKey(), taskId, true);
        await cancelTaskReminder(taskId);
        onTaskLaunch?.call(taskId, _taskDoneAction);
      } else {
        onTaskLaunch?.call(taskId, _taskFocusAction);
      }
    }
  }

  /// Handles the case where tapping a notification action launched the app.
  Future<void> consumeLaunchAction() async {
    await init();
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        final r = details!.notificationResponse;
        if (r != null) await _handleAction(r.actionId, r.payload);
      }
    } catch (_) {}
  }

  Future<void> requestPermissions() async {
    await init();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      if (!(await android?.canScheduleExactNotifications() ?? true)) {
        await android?.requestExactAlarmsPermission();
      }
    } catch (_) {}
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

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

  Future<void> scheduleFocusEnd(
    DateTime endAt,
    String taskTitle, {
    AppLanguage lang = AppLanguage.fa,
  }) async {
    await init();
    if (endAt.isBefore(DateTime.now())) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'focus_end',
        L10n.focusEndChannelName(lang),
        channelDescription: L10n.focusEndChannelName(lang),
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        color: _ember,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
    final when = tz.TZDateTime.from(endAt, tz.local);
    final title = L10n.focusEndTimeUpTitle(lang);
    final body = L10n.focusEndTimeUpBody(taskTitle, lang);
    try {
      await _plugin.zonedSchedule(
        id: _focusEndId,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: _focusEndId,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {}
    }
  }

  Future<void> cancelFocusEnd() async {
    await init();
    await _safeCancel(_focusEndId);
  }

  // ---------- habit reminders ----------

  static int habitNotifId(String habitId) {
    var hash = 0x811c9dc5;
    for (final c in habitId.codeUnits) {
      hash = ((hash ^ c) * 0x01000193) & 0x7fffffff;
    }
    return 10000 + (hash % 100000000);
  }

  Future<void> scheduleHabitReminder(
    Habit habit, {
    AppLanguage lang = AppLanguage.fa,
  }) async {
    await init();
    final id = habitNotifId(habit.id);
    final minutes = habit.reminderMinutes;
    if (minutes == null) {
      await _safeCancel(id);
      return;
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_cue',
        L10n.habitNotificationChannelName(lang),
        channelDescription: L10n.habitNotificationChannelName(lang),
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        color: _ember,
        actions: [
          AndroidNotificationAction(
            _habitDoneAction,
            L10n.habitNotificationActionDone(lang),
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        categoryIdentifier: _habitCategory,
      ),
    );
    await _safeZonedSchedule(
      id: id,
      title: L10n.habitNotificationCueTitle(habit.cue, lang),
      body: L10n.habitNotificationBody(
        isBad: habit.isBad,
        title: habit.title,
        replacement: habit.replacement,
        lang: lang,
      ),
      scheduledDate: _nextOccurrence(minutes),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: habit.id,
    );
  }

  Future<void> cancelHabitReminder(String habitId) async {
    await init();
    await _safeCancel(habitNotifId(habitId));
  }

  Future<void> syncHabitReminders(
    List<Habit> habits, {
    AppLanguage lang = AppLanguage.fa,
  }) async {
    for (final h in habits) {
      await scheduleHabitReminder(h, lang: lang);
    }
  }

  // ---------- task scheduled reminders ----------

  static int taskNotifId(String taskId) {
    var hash = 0x811c9dc5;
    for (final c in taskId.codeUnits) {
      hash = ((hash ^ c) * 0x01000193) & 0x7fffffff;
    }
    return 20000 + (hash % 100000000);
  }

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required int minutesOfDay,
    required String dayKey,
    AppLanguage lang = AppLanguage.fa,
  }) async {
    await init();
    final id = taskNotifId(taskId);

    final parts = dayKey.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final day = int.tryParse(parts[2]) ?? DateTime.now().day;

    final target = DateTime(
      year,
      month,
      day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );

    if (!target.isAfter(DateTime.now())) {
      await _safeCancel(id);
      return;
    }

    final when = tz.TZDateTime.from(target, tz.local);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminder',
        L10n.taskReminderChannelName(lang),
        channelDescription: L10n.taskReminderChannelName(lang),
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        color: _ember,
        actions: [
          AndroidNotificationAction(
            _taskFocusAction,
            L10n.focusButton(lang),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            _taskDoneAction,
            lang == AppLanguage.fa ? 'انجام شد' : 'Done',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        categoryIdentifier: _taskCategory,
      ),
    );

    await _safeZonedSchedule(
      id: id,
      title: L10n.taskReminderNotificationTitle(taskTitle, lang),
      body: L10n.taskReminderNotificationBody(lang),
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'task:$taskId',
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await init();
    await _safeCancel(taskNotifId(taskId));
  }

  // ---------- retention loop: morning / evening / weekly ----------

  tz.TZDateTime _nextOccurrence(int minutesOfDay, {bool skipToday = false}) {
    final now = DateTime.now();
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      minutesOfDay ~/ 60,
      minutesOfDay % 60,
    );
    if (skipToday || !target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(target, tz.local);
  }

  /// Re-plans the morning/evening nudges around today's actual state.
  Future<void> syncDailyReminders({
    required bool plannedToday,
    required bool closedToday,
    required int? morningMinutes,
    required int? eveningMinutes,
    AppLanguage lang = AppLanguage.fa,
  }) async {
    await init();
    await _safeCancel(_morningId);
    await _safeCancel(_eveningId);

    final quietDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_ritual',
        L10n.dailyRitualChannelName(lang),
        channelDescription: L10n.dailyRitualChannelName(lang),
        color: _ember,
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true),
    );

    if (morningMinutes != null) {
      await _safeZonedSchedule(
        id: _morningId,
        title: L10n.morningNotificationTitle(lang),
        body: L10n.morningNotificationBody(lang),
        scheduledDate: _nextOccurrence(morningMinutes, skipToday: plannedToday),
        notificationDetails: quietDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
    if (eveningMinutes != null) {
      await _safeZonedSchedule(
        id: _eveningId,
        title: L10n.eveningNotificationTitle(lang),
        body: L10n.eveningNotificationBody(lang),
        scheduledDate: _nextOccurrence(eveningMinutes, skipToday: closedToday),
        notificationDetails: quietDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    final now = DateTime.now();
    var weekly = DateTime(now.year, now.month, now.day, 20, 30);
    while (weekly.weekday != DateTime.friday || !weekly.isAfter(now)) {
      weekly = weekly.add(const Duration(days: 1));
    }
    await _safeZonedSchedule(
      id: _weeklyId,
      title: L10n.weeklyNotificationTitle(lang),
      body: L10n.weeklyNotificationBody(lang),
      scheduledDate: tz.TZDateTime.from(weekly, tz.local),
      notificationDetails: quietDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _safeCancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: androidScheduleMode,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    } catch (e) {
      debugPrint(
        'zonedSchedule failed for id $id with $androidScheduleMode: $e',
      );
      if (androidScheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: matchDateTimeComponents,
            payload: payload,
          );
        } catch (e2) {
          debugPrint('zonedSchedule fallback inexact failed for id $id: $e2');
        }
      }
    }
  }
}
