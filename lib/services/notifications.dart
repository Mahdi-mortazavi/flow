import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications: the end-of-focus alarm must fire even if the app is
/// killed, so it is scheduled on the OS at session start.
class Notifications {
  Notifications._();
  static final Notifications instance = Notifications._();

  static const _focusEndId = 1001;
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

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
    );
    _ready = true;
  }

  Future<void> requestPermissions() async {
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

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
        vibrationPattern: null,
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
}
