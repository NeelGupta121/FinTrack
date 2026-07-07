import 'dart:math';
import '../../domain/entities/holding.dart';

class BenchmarkResult {
  final double portfolioReturn;
  final double benchmarkReturn;
  final double alpha;

  const BenchmarkResult({required this.portfolioReturn, required this.benchmarkReturn, required this.alpha});
}

class DriftAlert {
  final String symbol;
  final double currentPct;
  final double targetPct;
  final double driftPct;

  const DriftAlert({required this.symbol, required this.currentPct, required this.targetPct, required this.driftPct});
}

class InvestmentTransaction {
  final double amount; // negative = outflow (buy), positive = inflow (sell/dividend)
  final DateTime date;
  const InvestmentTransaction({required this.amount, required this.date});
}

class AnalyzePortfolioUseCase {
  BenchmarkResult compareVsBenchmark(
    Map<String, double> portfolioPrices, // date -> portfolio value
    Map<String, double> benchmarkPrices, // date -> benchmark value
  ) {
    if (portfolioPrices.length < 2 || benchmarkPrices.length < 2) {
      return const BenchmarkResult(portfolioReturn: 0, benchmarkReturn: 0, alpha: 0);
    }
    final pKeys = portfolioPrices.keys.toList()..sort();
    final bKeys = benchmarkPrices.keys.toList()..sort();

    final pFirst = portfolioPrices[pKeys.first]!;
    final bFirst = benchmarkPrices[bKeys.first]!;
    // A 0 starting value has no defined percentage return; report 0 rather than
    // Infinity/NaN (which would corrupt alpha and crash chart widgets).
    final pReturn = pFirst == 0 ? 0.0 : (portfolioPrices[pKeys.last]! - pFirst) / pFirst * 100;
    final bReturn = bFirst == 0 ? 0.0 : (benchmarkPrices[bKeys.last]! - bFirst) / bFirst * 100;

    return BenchmarkResult(portfolioReturn: pReturn, benchmarkReturn: bReturn, alpha: pReturn - bReturn);
  }

  List<DriftAlert> detectDrift(List<Holding> holdings, {double threshold = 5.0}) {
    final total = holdings.fold<double>(0, (s, h) => s + h.investedValue);
    if (total == 0) return [];

    final alerts = <DriftAlert>[];
    for (final h in holdings) {
      if (h.targetAllocation == null) continue;
      final current = (h.investedValue / total) * 100;
      final drift = current - h.targetAllocation!;
      if (drift.abs() > threshold) {
        alerts.add(DriftAlert(symbol: h.symbol, currentPct: current, targetPct: h.targetAllocation!, driftPct: drift));
      }
    }
    return alerts;
  }

  /// Newton-Raphson XIRR calculation.
  double calculateXIRR(List<InvestmentTransaction> txns) {
    if (txns.length < 2) return 0;
    final sorted = List<InvestmentTransaction>.from(txns)..sort((a, b) => a.date.compareTo(b.date));
    final d0 = sorted.first.date;

    double xirr = 0.1; // initial guess
    bool clamped = false;
    for (int i = 0; i < 100; i++) {
      double f = 0, df = 0;
      for (final t in sorted) {
        final years = t.date.difference(d0).inDays / 365.25;
        final base = 1 + xirr;
        final denom = pow(base, years).toDouble();
        if (denom == 0 || !denom.isFinite) return 0; // diverged
        f += t.amount / denom;
        df -= years * t.amount / (denom * base);
      }
      if (df == 0 || !df.isFinite) break;
      var next = xirr - f / df;
      if (!next.isFinite) return 0; // diverged to NaN/Infinity
      if (next <= -1) {
        next = -0.9999; // keep (1 + xirr) positive for pow()
        clamped = true;
      }
      if ((next - xirr).abs() < 1e-7) {
        // Converging onto the divergence clamp is a non-convergence signal, not
        // a genuine -99.99% return — report 0 rather than a misleading rate.
        if (clamped && (next + 0.9999).abs() < 1e-5) return 0;
        return next;
      }
      xirr = next;
    }
    return xirr.isFinite ? xirr : 0;
  }
}
