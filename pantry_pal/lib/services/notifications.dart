import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/pantry_item.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'pantry_expiry';
  static const _channelName = 'Expiry reminders';
  static const _channelDesc = 'Reminds you when pantry items are about to expire';

  // Notification IDs are derived from item id + offset slot to avoid collisions.
  static const _daysBeforeOffsets = [7, 3, 1];

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
    );
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleForItem(PantryItem item) async {
    if (item.id == null || item.expiryDate == null) return;
    await cancelForItem(item.id!);

    final now = DateTime.now();
    for (var i = 0; i < _daysBeforeOffsets.length; i++) {
      final daysBefore = _daysBeforeOffsets[i];
      final fire = DateTime(
        item.expiryDate!.year,
        item.expiryDate!.month,
        item.expiryDate!.day,
        9,
      ).subtract(Duration(days: daysBefore));
      if (fire.isBefore(now)) continue;

      final id = _notificationId(item.id!, i);
      final title = daysBefore == 1
          ? '${item.name} expires tomorrow'
          : '${item.name} expires in $daysBefore days';

      await _plugin.zonedSchedule(
        id,
        title,
        'Use it up before it goes off.',
        tz.TZDateTime.from(fire, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelForItem(int itemId) async {
    for (var i = 0; i < _daysBeforeOffsets.length; i++) {
      await _plugin.cancel(_notificationId(itemId, i));
    }
  }

  int _notificationId(int itemId, int slot) => itemId * 10 + slot;
}
