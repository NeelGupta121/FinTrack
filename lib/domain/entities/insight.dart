import 'package:equatable/equatable.dart';

/// AI-generated insight entity.
class Insight extends Equatable {
  final String id;
  final String type; // anomaly, sentiment, rebalance, digest, tip
  final String title;
  final String body;
  final String severity; // info, warning, action
  final bool isRead;
  final DateTime createdAt;

  const Insight({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.severity = 'info',
    this.isRead = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
