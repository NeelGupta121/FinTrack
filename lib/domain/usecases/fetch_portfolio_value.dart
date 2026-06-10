import '../repositories/investment_repository.dart';

/// Fetch latest portfolio value with live prices.
class FetchPortfolioValue {
  final InvestmentRepository _repo;
  FetchPortfolioValue(this._repo);

  // TODO: Implement — get portfolio, fetch live prices, compute total
  Future<double> call() async {
    final portfolio = await _repo.getPortfolio();
    return portfolio.totalInvested; // placeholder — needs live prices
  }
}
