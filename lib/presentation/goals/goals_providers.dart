import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  double get progress => (currentAmount / targetAmount).clamp(0.0, 1.0);
  double get remaining => targetAmount - currentAmount;

  factory FinancialGoal.fromJson(Map<String, dynamic> json) => FinancialGoal(
        id: json['id'] as String,
        name: json['name'] as String,
        type: GoalType.values.byName(json['type'] as String? ?? 'custom'),
        targetAmount: (json['target_amount'] as num).toDouble(),
        currentAmount: (json['current_amount'] as num? ?? 0).toDouble(),
        deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
      );
}

final goalsListProvider = FutureProvider<List<FinancialGoal>>((ref) async {
  final response = await Supabase.instance.client.from('goals').select().order('created_at');
  return (response as List).map((e) => FinancialGoal.fromJson(e as Map<String, dynamic>)).toList();
});

final goalProgressProvider = Provider.family<Map<String, dynamic>, FinancialGoal>((ref, goal) {
  final monthlySavings = 5000.0; // TODO: calculate from actual income - expenses
  final remaining = goal.remaining;
  final monthsNeeded = remaining > 0 ? (remaining / monthlySavings).ceil() : 0;
  final eta = DateTime.now().add(Duration(days: monthsNeeded * 30));
  final onTrack = goal.deadline == null || eta.isBefore(goal.deadline!);

  return {
    'months_needed': monthsNeeded,
    'eta': eta,
    'on_track': onTrack,
    'monthly_needed': goal.deadline != null
        ? remaining / (goal.deadline!.difference(DateTime.now()).inDays / 30).ceil()
        : monthlySavings,
  };
});

final addGoalProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, data) async {
  await Supabase.instance.client.from('goals').insert(data);
  ref.invalidate(goalsListProvider);
});
