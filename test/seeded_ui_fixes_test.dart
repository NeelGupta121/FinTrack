// Regression tests for defects that only surfaced once the app held REAL data.
//
// Every one of these passed `flutter analyze` and the whole suite while being
// visibly wrong on screen, which is why they are pinned here rather than left
// to a screenshot review.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack/core/utils/currency_formatter.dart';
import 'package:fintrack/domain/usecases/detect_recurring_bills.dart';
import 'package:fintrack/presentation/common/widgets/category_catalog.dart';

void main() {
  group('CurrencyFormatter.digits — one money format app-wide', () {
    test('groups in Indian lakh style, not Western thousands', () {
      // The app previously rendered this same amount three ways depending on
      // screen: 4,48,518 / 448,518 / 448518.
      expect(CurrencyFormatter.digits.format(448518), '4,48,518');
      expect(CurrencyFormatter.digits.format(77048), '77,048');
      expect(CurrencyFormatter.digits.format(600000), '6,00,000');
    });

    test('drops fractions rather than leaking decimals into UI money', () {
      expect(CurrencyFormatter.digits.format(1609.4), '1,609');
      expect(CurrencyFormatter.digits.format(4889.6), '4,890');
    });

    test('carries the minus through for negative amounts', () {
      expect(CurrencyFormatter.digits.format(-19333), '-19,333');
    });

    test('grouped() prefixes the symbol', () {
      expect(CurrencyFormatter.grouped(55048), '₹55,048');
    });
  });

  group('CategoryCatalog.displayLabel — no raw slugs in the UI', () {
    test('known ids resolve to their catalogue label', () {
      expect(CategoryCatalog.displayLabel('food_delivery'), 'Food Delivery');
    });

    test('unknown ids de-slugify instead of collapsing to Other', () {
      // labelFor() erases unknowns to 'Other'; displayLabel must not, because
      // Insights renders this id inside a sentence.
      expect(CategoryCatalog.labelFor('mystery_spend'), 'Other');
      expect(CategoryCatalog.displayLabel('mystery_spend'), 'Mystery Spend');
      expect(CategoryCatalog.displayLabel('multi-word thing'), 'Multi Word Thing');
    });

    test('null and empty are named, not blank', () {
      expect(CategoryCatalog.displayLabel(null), 'Uncategorised');
      expect(CategoryCatalog.displayLabel('   '), 'Uncategorised');
    });

    test('never returns a string containing a raw separator', () {
      for (final id in ['food_delivery', 'transport_ride', 'bills_electricity']) {
        expect(CategoryCatalog.displayLabel(id), isNot(contains('_')));
      }
    });
  });

  group('DetectRecurringBills — a bill is money going OUT', () {
    /// Three monthly occurrences of a stable amount: qualifies on every axis
    /// except direction.
    List<Map<String, dynamic>> monthly({
      required String merchant,
      required double amount,
      required String type,
      String? categoryId,
    }) =>
        [
          for (var m = 0; m < 3; m++)
            {
              'merchant': merchant,
              'amount': amount,
              'type': type,
              'date': DateTime(2026, 5 + m, 5).toIso8601String(),
              if (categoryId != null) 'category_id': categoryId,
            }
        ];

    test('recurring income is NOT emitted as a bill', () {
      final bills = DetectRecurringBills().call([
        ...monthly(merchant: 'Upwork', amount: 22000, type: 'income'),
      ]);
      expect(bills, isEmpty,
          reason: 'a monthly salary/retainer satisfies every recurrence test, '
              'but it is not a subscription and must not inflate committed spend');
    });

    test('recurring expense is still detected alongside excluded income', () {
      final bills = DetectRecurringBills().call([
        ...monthly(merchant: 'Upwork', amount: 22000, type: 'income'),
        ...monthly(merchant: 'Netflix', amount: 649, type: 'expense'),
      ]);
      expect(bills.map((b) => b.merchant), ['Netflix']);
      // The whole point: the monthly-recurring total excludes the income.
      expect(bills.fold<double>(0, (s, b) => s + b.amount), 649);
    });

    test('rows with a missing type keep their previous behaviour', () {
      // Deliberate: exclude on explicit 'income' only, so legacy rows that
      // predate the type field are not silently dropped from detection.
      final untyped = [
        for (var m = 0; m < 3; m++)
          {
            'merchant': 'Legacy Co',
            'amount': 500.0,
            'date': DateTime(2026, 5 + m, 5).toIso8601String(),
          }
      ];
      expect(DetectRecurringBills().call(untyped).map((b) => b.merchant),
          ['Legacy Co']);
    });

    test('carries the dominant category so the row can show a real icon', () {
      final bills = DetectRecurringBills().call([
        ...monthly(
            merchant: 'Prestige Apartments',
            amount: 35000,
            type: 'expense',
            categoryId: 'rent'),
      ]);
      expect(bills.single.categoryId, 'rent');
      expect(CategoryCatalog.iconFor('rent'), isA<IconData>());
    });

    test('categoryId is null when no row carries one', () {
      final bills = DetectRecurringBills()
          .call(monthly(merchant: 'Airtel', amount: 999, type: 'expense'));
      expect(bills.single.categoryId, isNull,
          reason: 'the UI falls back to a generic icon, it must not guess');
    });
  });
}
