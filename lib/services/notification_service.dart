import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider((_) => NotificationService());

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
  }

  /// Lazily initializes the timezone database and the notifications plugin on
  /// first use, so callers never hit an uninitialized plugin (PlatformException)
  /// or an unset `tz.local` (LocationNotFound / wrong-time scheduling).
  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await init();
    // Android 13+ (API 33) and iOS require a runtime notification-permission
    // grant before any notification is delivered. Requested here on first use.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  Future<void> scheduleBillReminder(String merchant, DateTime dueDate, {int daysBefore = 3}) async {
    if (kIsWeb) return; // local notifications unavailable on web
    final scheduledDate = dueDate.subtract(Duration(days: daysBefore));
    if (scheduledDate.isBefore(DateTime.now())) return;

    await _ensureReady();
    await _plugin.zonedSchedule(
      merchant.hashCode,
      'Bill Due Soon',
      '$merchant payment due in $daysBefore days',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails('bills', 'Bill Reminders', importance: Importance.high),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  Future<void> scheduleGoalMilestone(String goalName, int percentReached) async {
    if (kIsWeb) return;
    await _ensureReady();
    await _plugin.show(
      goalName.hashCode + percentReached,
      '🎯 Goal Milestone!',
      '$goalName reached $percentReached%',
      const NotificationDetails(
        android: AndroidNotificationDetails('goals', 'Goal Milestones'),
      ),
    );
  }

  Future<void> budgetThresholdAlert(String category, double percentUsed) async {
    if (kIsWeb) return;
    if (percentUsed < 80) return;
    await _ensureReady();
    await _plugin.show(
      category.hashCode,
      '⚠️ Budget Alert',
      '$category spending at ${percentUsed.toStringAsFixed(0)}% of budget',
      const NotificationDetails(
        android: AndroidNotificationDetails('budget', 'Budget Alerts', importance: Importance.high),
      ),
    );
  }
}
