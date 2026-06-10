import 'package:equatable/equatable.dart';

/// Investment holding entity.
class Holding extends Equatable {
  final String id;
  final String symbol;
  final String name;
  final String type; // stock, mutual_fund, etf, bond, gold, crypto
  final double quantity;
  final double avgPrice;
  final String currency;
  final double? targetAllocation;

  const Holding({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.quantity,
    required this.avgPrice,
    this.currency = 'INR',
    this.targetAllocation,
  });

  double get investedValue => quantity * avgPrice;

  @override
  List<Object?> get props => [id];
}
