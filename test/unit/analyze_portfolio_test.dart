import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/domain/usecases/analyze_portfolio.dart';

void main() {
  final useCase = AnalyzePortfolioUseCase();

  group('compareVsBenchmark', () {
    test('computes returns and alpha for normal inputs', () {
      final r = useCase.compareVsBenchmark(
        {'2026-01-01': 100000, '2026-02-01': 110000}, // +10%
        {'2026-01-01': 20000, '2026-02-01': 21000}, //   +5%
      );
      expect(r.portfolioReturn, closeTo(10, 1e-9));
      expect(r.benchmarkReturn, closeTo(5, 1e-9));
      expect(r.alpha, closeTo(5, 1e-9));
    });

    test('does not produce Infinity/NaN when the first value is 0', () {
      final r = useCase.compareVsBenchmark(
        {'2026-01-01': 0.0, '2026-02-01': 50000}, // undefined %; must be 0
        {'2026-01-01': 20000, '2026-02-01': 22000}, // +10%
      );
      expect(r.portfolioReturn, 0.0);
      expect(r.portfolioReturn.isFinite, isTrue);
      expect(r.benchmarkReturn, closeTo(10, 1e-9));
      expect(r.alpha.isFinite, isTrue);
    });

    test('returns zeros when fewer than 2 data points', () {
      final r = useCase.compareVsBenchmark({'2026-01-01': 100}, {'2026-01-01': 100});
      expect(r.portfolioReturn, 0);
      expect(r.benchmarkReturn, 0);
      expect(r.alpha, 0);
    });
  });

  group('calculateXIRR', () {
    test('returns ~ -100%? no — a doubling in one year is ~+100%', () {
      // Invest 100k on Jan 1, worth 200k on Dec 31 (~1 year) -> ~+100% XIRR.
      final xirr = useCase.calculateXIRR([
        InvestmentTransaction(amount: -100000, date: DateTime(2026, 1, 1)),
        InvestmentTransaction(amount: 200000, date: DateTime(2026, 12, 31)),
      ]);
      expect(xirr.isFinite, isTrue);
      expect(xirr, greaterThan(0.9));
      expect(xirr, lessThan(1.1));
    });

    test('returns 0 for fewer than 2 transactions', () {
      expect(useCase.calculateXIRR([]), 0);
      expect(
        useCase.calculateXIRR([InvestmentTransaction(amount: -1000, date: DateTime(2026, 1, 1))]),
        0,
      );
    });

    test('never returns a non-finite value', () {
      final xirr = useCase.calculateXIRR([
        InvestmentTransaction(amount: -1, date: DateTime(2026, 1, 1)),
        InvestmentTransaction(amount: 1000000, date: DateTime(2026, 1, 2)),
      ]);
      expect(xirr.isFinite, isTrue);
    });
  });
}
