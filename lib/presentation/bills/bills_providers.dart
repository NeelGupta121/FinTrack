import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';
import '../../domain/usecases/detect_recurring_bills.dart';
import '../../services/notification_service.dart';

final recurringBillsProvider = FutureProvider<List<RecurringBill>>((ref) async {
  final detector = DetectRecurringBills();
  final txns = LocalDatabase.transactions.values
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  return detector.call(txns);
});

final upcomingBillsProvider = Provider<List<RecurringBill>>((ref) {
  final bills = ref.watch(recurringBillsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final cutoff = now.add(const Duration(days: 7));
  return bills.where((b) => b.nextDueDate.isBefore(cutoff) && b.nextDueDate.isAfter(now)).toList();
});

final billReminderProvider = Provider<void>((ref) {
  final upcoming = ref.watch(upcomingBillsProvider);
  final notifService = ref.watch(notificationServiceProvider);
  for (final bill in upcoming) {
    notifService.scheduleBillReminder(bill.merchant, bill.nextDueDate);
  }
});
