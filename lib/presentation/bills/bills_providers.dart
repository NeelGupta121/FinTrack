import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/detect_recurring_bills.dart';
import '../../services/notification_service.dart';

final recurringBillsProvider = FutureProvider<List<RecurringBill>>((ref) async {
  // In production, fetch from Supabase transactions table
  // For now, uses cached transaction history
  final detector = DetectRecurringBills();
  // TODO: wire to actual transaction provider
  return detector.call([]);
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
