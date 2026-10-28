import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Schedules local deadline reminders. Never throws: if notifications are
/// unavailable, the rest of the app keeps working.
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool ready = false;

  static Future<void> init() async {
    try {
      tz.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false),
      ));
      ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// True if the user allowed notifications.
  static Future<bool> requestPermission() async {
    if (!ready) return false;
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> sync(Task t) async {
    if (!ready) return;
    try {
      await _plugin.cancel(t.id);
      final at = t.remindAt;
      if (t.done || at == null || !at.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        t.id,
        'Due ${t.remind == Remind.dayBefore ? 'tomorrow' : 'today'}: ${t.title}',
        t.subject.isEmpty ? 'Open OqushyCompass to review it.' : t.subject,
        tz.TZDateTime.from(at, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails('deadlines', 'Deadlines',
              importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Could not schedule reminder: $e');
    }
  }

  /// One-off notification at a given time (used by the focus timer).
  static Future<void> scheduleAt(
      int id, String title, String body, DateTime at) async {
    if (!ready) return;
    try {
      await _plugin.cancel(id);
      if (!at.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails('timer', 'Focus timer',
              importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Could not schedule timer notification: $e');
    }
  }

  static Future<void> cancel(int id) async {
    if (!ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  static Future<void> syncAll(List<Task> tasks) async {
    for (final t in tasks) {
      await sync(t);
    }
  }
}
