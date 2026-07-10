import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/services/receipt_ocr_service.dart';

void main() {
  group('ReceiptOcrService.parseText', () {
    test('reads TOTAL without a currency symbol (was returning null)', () {
      const text = '''
FRESH MART
123 Main St
Item A 100.00
Item B 200.00
TOTAL 499.00
Date 05/01/2026
''';
      final r = ReceiptOcrService.parseText(text);
      expect(r.amount, 499.00);
      expect(r.merchant, 'FRESH MART');
      expect(r.date, DateTime(2026, 1, 5));
    });

    test('prefers the grand-total value with a currency symbol', () {
      const text = 'Cafe Coffee\nSubtotal Rs.1,100.00\nGRAND TOTAL Rs.1,234.56';
      final r = ReceiptOcrService.parseText(text);
      expect(r.amount, 1234.56);
    });

    test('falls back to currency-prefixed amount when no total keyword', () {
      const text = 'Store XYZ\nPaid ₹350.00';
      final r = ReceiptOcrService.parseText(text);
      expect(r.amount, 350.00);
    });

    test('falls back to the largest bare decimal when no symbol/keyword', () {
      const text = 'QUICK BITE\nBurger 150.00\nFries 75.50\n299.00';
      final r = ReceiptOcrService.parseText(text);
      expect(r.amount, 299.00);
    });

    test('returns null amount when there is no number at all', () {
      final r = ReceiptOcrService.parseText('THANK YOU\nVISIT AGAIN');
      expect(r.amount, isNull);
    });
  });
}
