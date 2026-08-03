import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../domain/usecases/financial_wellness.dart';
import '../expenses/expense_providers.dart';
import '../investments/investment_providers.dart';

/// NOTE: monthlyIncomeProvider now lives in expense_providers.dart (imported
/// below) so that AddExpenseNotifier can invalidate it on every mutation — it
/// reads the transactions box directly and a Hive write does not rebuild it.

/// "In My Pocket" — budget left for the rest of the month + a per-day allowance.
final safeToSpendProvider = FutureProvider.autoDispose<SafeToSpend>((ref) async {
  final summary = await ref.watch(monthlySummaryProvider.future);
  return FinancialWellness.safeToSpend(
    budget: summary.budget,
    spent: summary.totalSpent,
    now: DateTime.now(),
  );
});

/// Rule-based 0-100 financial health score with its factor breakdown.
final healthScoreProvider = FutureProvider.autoDispose<HealthScore>((ref) async {
  try {
    final summary = await ref.watch(monthlySummaryProvider.future);
    final income = ref.watch(monthlyIncomeProvider);
    final allocation = await ref.watch(portfolioAllocationProvider.future);
    final byType = <String, double>{for (final a in allocation) a.type: a.value};

    return FinancialWellness.healthScore(
      budget: summary.budget,
      spentThisMonth: summary.totalSpent,
      incomeThisMonth: income,
      holdingValueByType: byType,
      now: DateTime.now(),
    );
  } catch (e, st) {
    AppLogger.error('Failed to compute health score', tag: 'Wellness', error: e, stackTrace: st);
    rethrow;
  }
});

/// NOTE: section80cProvider lives in investment_providers.dart and
/// spendingTrendProvider lives in expense_providers.dart — each sits next to the
/// notifier that mutates its underlying box so writes can invalidate them.
/// Providers that read Hive directly are NOT auto-refreshed by a box write.
