import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_database.dart';

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

final goalsListProvider = FutureProvider<List<FinancialGoal>>((ref) async {
  final items = LocalDatabase.goals.values.toList();
  items.sort((a, b) => (a['created_at'] as String? ?? '').compareTo(b['created_at'] as String? ?? ''));
  return items.map((e) => FinancialGoal.fromJson(Map<String, dynamic>.from(e))).toList();
});

final goalProgressProvider = Provider.family<Map<String, dynamic>, FinancialGoal>((ref, goal) {
  final monthlySavings = 5000.0;
  final remaining = goal.remaining;
  final monthsNeeded = remaining > 0 ? (remaining / monthlySavings).ceil() : 0;
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

final addGoalProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, data) async {
  final id = LocalDatabase.newId();
  await LocalDatabase.goals.put(id, {
    'id': id,
    'created_at': DateTime.now().toIso8601String(),
    ...data,
  });
  ref.invalidate(goalsListProvider);
});
