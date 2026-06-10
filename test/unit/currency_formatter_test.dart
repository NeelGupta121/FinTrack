import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    group('formatINR', () {
      test('formats standard amount with ₹ symbol', () {
        expect(CurrencyFormatter.formatINR(1234.56), contains('1,234.56'));
        expect(CurrencyFormatter.formatINR(1234.56), startsWith('₹'));
      });

      test('handles zero', () {
        expect(CurrencyFormatter.formatINR(0), contains('0.00'));
      });

      test('handles negative amounts', () {
        final result = CurrencyFormatter.formatINR(-5000);
        expect(result, contains('5,000.00'));
        expect(result, contains('-'));
      });
    });

    group('compact', () {
      test('formats crores correctly', () {
        expect(CurrencyFormatter.compact(15000000), '₹1.50 Cr');
        expect(CurrencyFormatter.compact(10000000), '₹1.00 Cr');
      });

      test('formats lakhs correctly', () {
        expect(CurrencyFormatter.compact(250000), '₹2.50 L');
        expect(CurrencyFormatter.compact(100000), '₹1.00 L');
      });

      test('falls back to formatINR below 1 lakh', () {
        final result = CurrencyFormatter.compact(50000);
        expect(result, contains('₹'));
        expect(result, contains('50,000'));
      });

      test('handles zero', () {
        final result = CurrencyFormatter.compact(0);
        expect(result, contains('0.00'));
      });

      test('handles negative amounts in compact', () {
        final result = CurrencyFormatter.compact(-20000000);
        expect(result, contains('Cr'));
      });
    });
  });
}
