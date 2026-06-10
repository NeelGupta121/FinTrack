import '../entities/holding.dart';
import '../entities/portfolio.dart';

/// Contract for investment/portfolio data operations.
abstract class InvestmentRepository {
  Future<Portfolio> getPortfolio();
  Future<Holding> addHolding(Holding holding);
  Future<void> updateHolding(Holding holding);
  Future<double> getCurrentPrice(String symbol);
  // TODO: getTransactionHistory, getXIRR
}
