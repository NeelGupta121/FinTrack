import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/domain/usecases/net_worth.dart';

AccountBalance _a(String name, AccountKind k, double bal) =>
    AccountBalance(id: name, name: name, kind: k, balance: bal);

void main() {
  group('AccountKind', () {
    test('classifies liabilities correctly', () {
      expect(AccountKind.bank.isLiability, isFalse);
      expect(AccountKind.cash.isLiability, isFalse);
      expect(AccountKind.wallet.isLiability, isFalse);
      expect(AccountKind.fd.isLiability, isFalse);
      expect(AccountKind.creditCard.isLiability, isTrue);
      expect(AccountKind.loan.isLiability, isTrue);
    });

    test('fromId round-trips and falls back to bank on unknown', () {
      for (final k in AccountKind.values) {
        expect(AccountKind.fromId(k.id), k);
      }
      expect(AccountKind.fromId('nonsense'), AccountKind.bank);
      expect(AccountKind.fromId(null), AccountKind.bank);
    });
  });

  group('AccountBalance.signedValue', () {
    test('liability balances are negative contributions', () {
      expect(_a('HDFC', AccountKind.bank, 100000).signedValue, 100000);
      expect(_a('Amex', AccountKind.creditCard, 40000).signedValue, -40000);
    });
  });

  group('NetWorthCalculator.compute', () {
    test('nets cash + investments against debts', () {
      final nw = NetWorthCalculator.compute(
        accounts: [
          _a('HDFC', AccountKind.bank, 200000),
          _a('Cash', AccountKind.cash, 5000),
          _a('Amex', AccountKind.creditCard, 40000),
          _a('Car loan', AccountKind.loan, 300000),
        ],
        investments: 150000,
      );
      expect(nw.cashAssets, 205000);
      expect(nw.investments, 150000);
      expect(nw.liabilities, 340000);
      expect(nw.totalAssets, 355000);
      expect(nw.netWorth, 15000);
      expect(nw.isEmpty, isFalse);
    });

    test('can go negative when debts exceed assets', () {
      final nw = NetWorthCalculator.compute(
        accounts: [_a('Loan', AccountKind.loan, 500000)],
        investments: 100000,
      );
      expect(nw.netWorth, -400000);
    });

    test('is empty with no accounts and no investments', () {
      final nw = NetWorthCalculator.compute(accounts: const [], investments: 0);
      expect(nw.isEmpty, isTrue);
      expect(nw.netWorth, 0);
      expect(nw.debtToAssetRatio, isNull); // undefined, not infinite
    });

    test('debt-to-asset ratio is computed only when assets exist', () {
      final nw = NetWorthCalculator.compute(
        accounts: [_a('HDFC', AccountKind.bank, 100000), _a('CC', AccountKind.creditCard, 25000)],
        investments: 0,
      );
      expect(nw.debtToAssetRatio, closeTo(0.25, 0.0001));
    });
  });

  group('NetWorthCalculator.appendDaily', () {
    test('keeps one point per day, latest value wins', () {
      final now = DateTime(2026, 7, 31, 10);
      var h = NetWorthCalculator.appendDaily(const [], 1000, now: now);
      h = NetWorthCalculator.appendDaily(h, 1200, now: DateTime(2026, 7, 31, 18));
      expect(h, hasLength(1));
      expect(h.single.value, 1200);
    });

    test('accumulates across days in chronological order', () {
      var h = NetWorthCalculator.appendDaily(const [], 100, now: DateTime(2026, 7, 29));
      h = NetWorthCalculator.appendDaily(h, 200, now: DateTime(2026, 7, 30));
      h = NetWorthCalculator.appendDaily(h, 150, now: DateTime(2026, 7, 31));
      expect(h.map((p) => p.value).toList(), [100, 200, 150]);
    });

    test('caps the series length, dropping the oldest', () {
      var h = <NetWorthPoint>[];
      for (var i = 1; i <= 8; i++) {
        h = NetWorthCalculator.appendDaily(h, i * 10,
            now: DateTime(2026, 7, i), maxPoints: 5);
      }
      expect(h, hasLength(5));
      expect(h.first.value, 40); // days 1-3 dropped
      expect(h.last.value, 80);
    });
  });

  group('NetWorthCalculator.changeSinceStart', () {
    test('is the difference between first and last readings', () {
      final h = [
        NetWorthPoint(date: DateTime(2026, 7, 1), value: 1000),
        NetWorthPoint(date: DateTime(2026, 7, 31), value: 2500),
      ];
      expect(NetWorthCalculator.changeSinceStart(h), 1500);
    });

    test('is null with fewer than two readings', () {
      expect(NetWorthCalculator.changeSinceStart(const []), isNull);
      expect(
          NetWorthCalculator.changeSinceStart(
              [NetWorthPoint(date: DateTime(2026, 7, 1), value: 10)]),
          isNull);
    });
  });

  group('NetWorthPoint json', () {
    test('round-trips', () {
      final p = NetWorthPoint(date: DateTime(2026, 7, 31), value: 1234.5);
      final back = NetWorthPoint.fromJson(p.toJson());
      expect(back, isNotNull);
      expect(back!.value, 1234.5);
      expect(back.date, DateTime(2026, 7, 31));
    });

    test('returns null on malformed input instead of throwing', () {
      expect(NetWorthPoint.fromJson(null), isNull);
      expect(NetWorthPoint.fromJson('nope'), isNull);
      expect(NetWorthPoint.fromJson({'date': 'bad', 'value': 1}), isNull);
      expect(NetWorthPoint.fromJson({'date': '2026-07-31'}), isNull);
    });
  });
}
