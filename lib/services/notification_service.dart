import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

final notificationServiceProvider = Provider((_) => NotificationService());

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
  }

  Future<void> scheduleBillReminder(String merchant, DateTime dueDate, {int daysBefore = 3}) async {
    final scheduledDate = dueDate.subtract(Duration(days: daysBefore));
    if (scheduledDate.isBefore(DateTime.now())) return;

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
    if (percentUsed < 80) return;
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
