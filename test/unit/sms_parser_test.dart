import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/services/sms_parser_service.dart';

void main() {
  late SmsParserService parser;

  setUp(() => parser = SmsParserService());

  group('SmsParserService', () {
    test('parses HDFC debit SMS correctly', () {
      final result = parser.parse(
        'Rs.1,234.50 debited from a/c **4567 on 10-Jun-25 to AMAZON',
      );
      expect(result, isNotNull);
      expect(result!.amount, 1234.50);
    });

    test('parses SBI debit SMS correctly', () {
      final result = parser.parse(
        'Your a/c X9876 debited by Rs.500.00 on 10-Jun-25',
      );
      expect(result, isNotNull);
      expect(result!.amount, 500.00);
    });

    test('parses UPI payment SMS correctly', () {
      final result = parser.parse('Paid Rs.100.00 to merchant@upi ref 123');
      expect(result, isNotNull);
      expect(result!.amount, 100.00);
    });

    test('returns null for non-bank SMS', () {
      expect(parser.parse('Your OTP is 123456'), isNull);
      expect(parser.parse('Flash sale 50% off!'), isNull);
    });

    test('handles commas in large amounts', () {
      final result = parser.parse(
        'Rs.10,00,000.00 debited from a/c **1234 on 01-Jan-26',
      );
      expect(result, isNotNull);
      expect(result!.amount, 1000000.00);
    });

    test('handles amounts without decimals', () {
      final result = parser.parse('Paid Rs.5000 to shop@upi');
      expect(result, isNotNull);
      expect(result!.amount, 5000.0);
    });
  });
}
