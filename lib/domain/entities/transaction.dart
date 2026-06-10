import 'package:equatable/equatable.dart';

/// Core transaction entity.
class Transaction extends Equatable {
  final String id;
  final double amount;
  final String currency;
  final String type; // expense, income, transfer
  final String? description;
  final String? merchant;
  final DateTime date;
  final String? categoryId;
  final String source; // manual, sms, ocr, import

  const Transaction({
    required this.id,
    required this.amount,
    this.currency = 'INR',
    required this.type,
    this.description,
    this.merchant,
    required this.date,
    this.categoryId,
    this.source = 'manual',
  });

  @override
  List<Object?> get props => [id];
}
