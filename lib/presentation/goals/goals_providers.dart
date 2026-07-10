import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';
import '../../services/notification_service.dart';

enum GoalType { emergency, retirement, purchase, travel, education, custom }

class FinancialGoal {
  final String id;
  final String name;
  final GoalType type;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;

  const FinancialGoal({
    required this.id,
    required this.name,
    required this.type,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
  });

  double get progress => targetAmount == 0 ? 0.0 : (currentAmount / targetAmount).clamp(0.0, 1.0);
  double get remaining => targetAmount - currentAmount;

  factory FinancialGoal.fromJson(Map<String, dynamic> json) => FinancialGoal(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        type: GoalType.values.byName(json['type'] as String? ?? 'custom'),
        targetAmount: (json['target_amount'] as num? ?? 0).toDouble(),
        currentAmount: (json['current_amount'] as num? ?? 0).toDouble(),
        deadline: json['deadline'] != null ? DateTime.tryParse(json['deadline'] as String) : null,
      );
}

final goalsListProvider = FutureProvider.autoDispose<List<FinancialGoal>>((ref) async {
  final items = LocalDatabase.goals.values.toList();
  items.sort((a, b) => (a['created_at'] as String? ?? '').compareTo(b['created_at'] as String? ?? ''));
  return items.map((e) => FinancialGoal.fromJson(Map<String, dynamic>.from(e))).toList();
});

final goalProgressProvider = Provider.autoDispose.family<Map<String, dynamic>, FinancialGoal>((ref, goal) {
  const monthlySavings = 5000.0;
  final remaining = goal.remaining;
  // Cap to keep eta within valid DateTime range for astronomical targets.
  final monthsNeeded = remaining > 0 ? min((remaining / monthlySavings).ceil(), 12000) : 0;
  final eta = DateTime.now().add(Duration(days: monthsNeeded * 30));
  final onTrack = goal.deadline == null || eta.isBefore(goal.deadline!);

  return {
    'months_needed': monthsNeeded,
    'eta': eta,
    'on_track': onTrack,
    'monthly_needed': goal.deadline != null
        ? remaining / max(1, (goal.deadline!.difference(DateTime.now()).inDays / 30).ceil())
        : monthlySavings,
  };
});

final addGoalProvider = FutureProvider.autoDispose.family<void, Map<String, dynamic>>((ref, data) async {
  final id = LocalDatabase.newId();
  await LocalDatabase.goals.put(id, {
    'id': id,
    'created_at': DateTime.now().toIso8601String(),
    ...data,
  });
  ref.invalidate(goalsListProvider);
});

/// Add a contribution to an existing goal's saved amount. Previously goals were
/// create-only (current_amount stuck at 0), so progress never advanced. The new
/// total is clamped to [0, target] so a goal maxes out at 100% ("Done").
final addFundsProvider =
    FutureProvider.autoDispose.family<void, ({String goalId, double amount})>((ref, args) async {
  final raw = LocalDatabase.goals.get(args.goalId);
  if (raw == null) return;
  final map = Map<String, dynamic>.from(raw);
  final current = (map['current_amount'] as num? ?? 0).toDouble();
  final target = (map['target_amount'] as num? ?? 0).toDouble();
  final next = current + args.amount;
  final updated = target > 0 ? next.clamp(0.0, target) : max(0.0, next);
  map['current_amount'] = updated;
  await LocalDatabase.goals.put(args.goalId, map);
  ref.invalidate(goalsListProvider);

  // Fire a milestone notification for the highest threshold newly crossed
  // (no-op on web). Distinct notification IDs per milestone avoid dupes.
  if (target > 0) {
    final oldPct = current / target * 100;
    final newPct = updated / target * 100;
    int? crossed;
    for (final m in [25, 50, 75, 100]) {
      if (oldPct < m && newPct >= m) crossed = m;
    }
    if (crossed != null) {
      unawaited(ref.read(notificationServiceProvider).scheduleGoalMilestone(
            map['name'] as String? ?? 'Goal',
            crossed,
          ));
    }
  }
});
